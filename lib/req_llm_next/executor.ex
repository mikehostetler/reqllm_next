defmodule ReqLlmNext.Executor do
  @moduledoc """
  Central pipeline orchestration for ReqLLM v2.

  The Executor implements a 6-step pipeline:
  1. ModelResolver - LLMDB + config overrides
  2. Validation - Modalities, operation compatibility (stub)
  3. Constraints - Parameter transforms from metadata (stub)
  4. Adapter Pipeline - Per-model customizations
  5. Wire Protocol - JSON encode/decode per API family
  6. Provider HTTP - Base URL, auth, Finch orchestration
  """

  alias ReqLlmNext.Adapters.Pipeline, as: AdapterPipeline

  alias ReqLlmNext.{
    Constraints,
    Context,
    Error,
    Fixtures,
    ModelResolver,
    Response,
    Schema,
    StreamResponse,
    Validation
  }

  alias ReqLlmNext.Executor.StreamState
  alias ReqLlmNext.Wire.{Resolver, Streaming}

  @default_stream_timeout Application.compile_env(:req_llm_next, :stream_timeout, 30_000)

  @spec generate_text(String.t(), String.t() | Context.t(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def generate_text(model_spec, prompt, opts \\ []) do
    with {:ok, %StreamResponse{} = stream_resp} <- stream_text(model_spec, prompt, opts),
         {:ok, context} <- Context.normalize(prompt) do
      stream = stream_resp.stream
      model = stream_resp.model

      streaming_response = %Response{
        id: generate_id(),
        model: model,
        context: context,
        message: nil,
        stream?: true,
        stream: stream,
        usage: nil,
        finish_reason: nil
      }

      Response.join_stream(streaming_response)
    end
  end

  defp generate_id do
    Uniq.UUID.uuid7()
  end

  @spec stream_text(String.t(), String.t(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_text(model_spec, prompt, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         :ok <- Validation.validate_stream!(model, prompt, opts),
         opts <- Constraints.apply(model, opts),
         opts <- AdapterPipeline.apply(model, opts),
         %{provider_mod: provider_mod, wire_mod: wire_mod} <- Resolver.resolve!(model) do
      case Fixtures.maybe_replay_stream(model, prompt, opts) do
        {:ok, replay_stream} ->
          {:ok, %StreamResponse{stream: replay_stream, model: model}}

        :no_fixture ->
          with {:ok, finch_request} <-
                 Streaming.build_request(provider_mod, wire_mod, model, prompt, opts),
               {:ok, stream} <- start_stream(finch_request, model, wire_mod, prompt, opts) do
            {:ok, %StreamResponse{stream: stream, model: model}}
          end
      end
    end
  end

  @spec stream_object(String.t(), String.t(), term(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_object(model_spec, prompt, object_schema, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         :ok <- Validation.validate_stream!(model, prompt, opts),
         {:ok, compiled_schema} <- ReqLlmNext.Schema.compile(object_schema),
         opts <-
           opts
           |> Keyword.put(:operation, :object)
           |> Keyword.put(:compiled_schema, compiled_schema),
         opts <- Constraints.apply(model, opts),
         opts <- AdapterPipeline.apply(model, opts),
         %{provider_mod: provider_mod, wire_mod: wire_mod} <- Resolver.resolve!(model) do
      case Fixtures.maybe_replay_stream(model, prompt, opts) do
        {:ok, replay_stream} ->
          {:ok, %StreamResponse{stream: replay_stream, model: model}}

        :no_fixture ->
          with {:ok, finch_request} <-
                 Streaming.build_request(provider_mod, wire_mod, model, prompt, opts),
               {:ok, stream} <- start_stream(finch_request, model, wire_mod, prompt, opts) do
            {:ok, %StreamResponse{stream: stream, model: model}}
          end
      end
    end
  end

  @spec generate_object(String.t(), String.t() | Context.t(), term(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def generate_object(model_spec, prompt, object_schema, opts \\ []) do
    with {:ok, compiled_schema} <- Schema.compile(object_schema),
         {:ok, %StreamResponse{} = stream_resp} <-
           stream_object(model_spec, prompt, object_schema, opts),
         {:ok, context} <- Context.normalize(prompt) do
      json_text = StreamResponse.text(stream_resp)
      model = stream_resp.model

      case Jason.decode(json_text) do
        {:ok, object} ->
          case Schema.validate(object, compiled_schema) do
            {:ok, validated_object} ->
              {:ok, build_object_response(model, validated_object, context)}

            {:error, {:validation_errors, errors}} ->
              {:error,
               Error.API.SchemaValidation.exception(
                 message: "Schema validation failed",
                 errors: errors,
                 value: object
               )}
          end

        {:error, jason_error} ->
          {:error,
           Error.API.JsonParse.exception(
             message: "Failed to parse JSON: #{Exception.message(jason_error)}",
             raw_json: json_text
           )}
      end
    end
  end

  defp build_object_response(model, object, context) do
    message = %Context.Message{
      role: :assistant,
      content: [Context.ContentPart.text(Jason.encode!(object))],
      metadata: %{}
    }

    updated_context = Context.append(context, message)

    %Response{
      id: generate_id(),
      model: model,
      context: updated_context,
      message: message,
      object: object,
      stream?: false,
      stream: nil,
      usage: nil,
      finish_reason: :stop
    }
  end

  defp start_stream(finch_request, model, wire_mod, prompt, opts) do
    recorder = maybe_start_recorder(model, prompt, finch_request, opts)
    receive_timeout = Keyword.get(opts, :receive_timeout, @default_stream_timeout)

    stream =
      Stream.resource(
        fn -> start_finch_stream(finch_request, recorder, wire_mod, receive_timeout) end,
        fn state -> next_chunk(state) end,
        fn state -> cleanup(state) end
      )

    {:ok, stream}
  end

  defp maybe_start_recorder(model, prompt, finch_request, opts) do
    case {Fixtures.mode(), Keyword.get(opts, :fixture)} do
      {:record, fixture_name} when is_binary(fixture_name) ->
        Fixtures.start_recorder(model, fixture_name, prompt, finch_request)

      _ ->
        nil
    end
  end

  defp start_finch_stream(finch_request, recorder, wire_mod, receive_timeout) do
    parent = self()
    ref = make_ref()

    task =
      Task.async(fn ->
        Finch.stream(finch_request, ReqLlmNext.Finch, nil, fn
          {:status, status}, _acc ->
            send(parent, {ref, :status, status})
            nil

          {:headers, headers}, _acc ->
            send(parent, {ref, :headers, headers})
            nil

          {:data, data}, _acc ->
            send(parent, {ref, :data, data})
            nil
        end)

        send(parent, {ref, :done})
      end)

    %{
      ref: ref,
      task: task,
      stream_state: StreamState.new(recorder, wire_mod),
      receive_timeout: receive_timeout
    }
  end

  defp next_chunk(%{ref: ref, stream_state: stream_state, receive_timeout: timeout} = state) do
    receive do
      {^ref, :status, status} ->
        handle_stream_result(StreamState.handle_message({:status, status}, stream_state), state)

      {^ref, :headers, headers} ->
        handle_stream_result(StreamState.handle_message({:headers, headers}, stream_state), state)

      {^ref, :data, data} ->
        handle_stream_result(StreamState.handle_message({:data, data}, stream_state), state)

      {^ref, :done} ->
        handle_stream_result(StreamState.handle_message(:done, stream_state), state)
    after
      timeout ->
        new_stream_state = StreamState.handle_timeout(stream_state)
        {:halt, %{state | stream_state: new_stream_state}}
    end
  end

  defp handle_stream_result({:cont, [], new_stream_state}, state) do
    next_chunk(%{state | stream_state: new_stream_state})
  end

  defp handle_stream_result({:cont, chunks, new_stream_state}, state) do
    {chunks, %{state | stream_state: new_stream_state}}
  end

  defp handle_stream_result({:halt, new_stream_state}, state) do
    {:halt, %{state | stream_state: new_stream_state}}
  end

  defp cleanup(%{task: task}) do
    Task.shutdown(task, :brutal_kill)
    :ok
  end

  @spec embed(String.t(), String.t() | [String.t()], keyword()) ::
          {:ok, [float()] | [[float()]]} | {:error, term()}
  def embed(model_spec, input, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         :ok <- Validation.validate!(model, :embed, nil, opts),
         :ok <- validate_embedding_input(input),
         %{provider_mod: provider_mod, wire_mod: wire_mod} <- Resolver.resolve!(model, :embed),
         {:ok, raw_response} <-
           execute_embedding_request(provider_mod, wire_mod, model, input, opts) do
      wire_mod.extract_embeddings(raw_response, input)
    end
  end

  defp validate_embedding_input("") do
    {:error, Error.Invalid.Parameter.exception(parameter: "input: cannot be empty")}
  end

  defp validate_embedding_input(text) when is_binary(text), do: :ok

  defp validate_embedding_input([]) do
    {:error, Error.Invalid.Parameter.exception(parameter: "input: cannot be empty list")}
  end

  defp validate_embedding_input(texts) when is_list(texts) do
    if Enum.all?(texts, &is_binary/1) do
      if Enum.any?(texts, &(&1 == "")) do
        {:error, Error.Invalid.Parameter.exception(parameter: "input: contains empty string")}
      else
        :ok
      end
    else
      {:error, Error.Invalid.Parameter.exception(parameter: "input: all items must be strings")}
    end
  end

  defp validate_embedding_input(_) do
    {:error,
     Error.Invalid.Parameter.exception(parameter: "input: must be string or list of strings")}
  end

  defp execute_embedding_request(provider_mod, wire_mod, model, input, opts) do
    api_key = provider_mod.get_api_key(opts)
    base_url = Keyword.get(opts, :base_url, provider_mod.base_url())
    url = base_url <> wire_mod.path()

    wire_headers = get_wire_headers(wire_mod, opts)

    headers =
      provider_mod.auth_headers(api_key) ++
        wire_headers

    body =
      wire_mod.encode_body(model, input, opts)
      |> Jason.encode!()

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, ReqLlmNext.Finch) do
      {:ok, %Finch.Response{status: status, body: response_body}} when status in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, decoded} ->
            {:ok, decoded}

          {:error, jason_error} ->
            {:error,
             Error.API.JsonParse.exception(
               message: "Failed to parse embedding response: #{Exception.message(jason_error)}",
               raw_json: response_body
             )}
        end

      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:error,
         Error.API.Request.exception(
           reason: "Embedding request failed",
           status: status,
           response_body: response_body
         )}

      {:error, reason} ->
        {:error, Error.API.Request.exception(reason: "HTTP request failed: #{inspect(reason)}")}
    end
  end

  defp get_wire_headers(wire_mod, opts) do
    if function_exported?(wire_mod, :headers, 1) do
      wire_mod.headers(opts)
    else
      [{"Content-Type", "application/json"}]
    end
  end
end
