defmodule ReqLlmNext.Fixtures do
  @moduledoc """
  Fixture system for ReqLlmNext streaming tests.

  Records raw SSE chunks at the Finch level for full pipeline replay.
  During replay, SSE decoding uses the same wire module as live requests,
  ensuring consistent behavior.

  - Controlled via REQ_LLM_NEXT_FIXTURES_MODE env var: "record" | "replay"
  - Files live under test/fixtures/
  - Format matches req_llm: request/response metadata + b64-encoded raw SSE chunks
  """

  alias ReqLlmNext.{ExecutionModules, ModelProfile, Telemetry}

  @root Path.expand("../../test/fixtures", __DIR__)

  @type mode :: :record | :replay

  @spec mode() :: mode()
  def mode do
    case System.get_env("REQ_LLM_NEXT_FIXTURES_MODE") do
      "record" -> :record
      _ -> :replay
    end
  end

  @spec path(LLMDB.Model.t(), String.t()) :: String.t()
  def path(%LLMDB.Model{} = model, fixture_name) do
    provider = Atom.to_string(model.provider)

    safe_model_id =
      model.id
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")

    safe_name =
      fixture_name
      |> Path.basename()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")

    Path.join([@root, provider, safe_model_id, "#{safe_name}.json"])
  end

  @doc """
  In replay mode with a fixture configured, returns a stream that replays
  raw SSE chunks through ServerSentEvents.parse/1 and the wire module.
  """
  @spec maybe_replay_stream(LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, Enumerable.t()} | :no_fixture
  def maybe_replay_stream(model, _prompt, opts) do
    case {mode(), Keyword.get(opts, :fixture)} do
      {:replay, fixture_name} when is_binary(fixture_name) ->
        fixture_path = path(model, fixture_name)

        case File.read(fixture_path) do
          {:ok, contents} ->
            fixture = Jason.decode!(contents)
            runtime = replay_runtime(fixture, model, opts)
            stream = build_replay_stream(fixture, runtime, model)
            Telemetry.emit_fixture(:replay, fixture_metadata(model, fixture_name, fixture))
            {:ok, stream}

          {:error, _} ->
            raise """
            Fixture not found: #{fixture_path}
            Run with REQ_LLM_NEXT_FIXTURES_MODE=record to create it.
            """
        end

      _ ->
        :no_fixture
    end
  end

  @spec maybe_replay_request(LLMDB.Model.t(), term(), keyword(), module()) ::
          {:ok, term()} | :no_fixture
  def maybe_replay_request(model, input, opts, wire_mod) do
    case {mode(), Keyword.get(opts, :fixture)} do
      {:replay, fixture_name} when is_binary(fixture_name) ->
        fixture_path = path(model, fixture_name)

        case File.read(fixture_path) do
          {:ok, contents} ->
            fixture = Jason.decode!(contents)
            Telemetry.emit_fixture(:replay, fixture_metadata(model, fixture_name, fixture))
            replay_request_fixture(fixture, wire_mod, model, input, opts)

          {:error, _} ->
            raise """
            Fixture not found: #{fixture_path}
            Run with REQ_LLM_NEXT_FIXTURES_MODE=record to create it.
            """
        end

      _ ->
        :no_fixture
    end
  end

  defp build_replay_stream(%{"chunks" => chunks} = fixture, runtime, model) do
    case request_transport(fixture) do
      "websocket" ->
        build_websocket_replay_stream(chunks, runtime, model)

      "local_process" ->
        build_framed_replay_stream(chunks, runtime, model)

      _ ->
        build_sse_replay_stream(chunks, runtime, model)
    end
  end

  defp build_sse_replay_stream(chunks, %{wire_mod: wire_mod, protocol_mod: protocol_mod}, model) do
    Stream.resource(
      fn -> {chunks, ""} end,
      fn
        {[], _buffer} ->
          {:halt, nil}

        {[b64_chunk | rest], buffer} ->
          raw_data = Base.decode64!(b64_chunk)
          new_buffer = buffer <> raw_data
          {events, remaining} = ServerSentEvents.parse(new_buffer)

          text_chunks =
            events
            |> Enum.flat_map(&wire_mod.decode_wire_event/1)
            |> Enum.flat_map(&protocol_mod.decode_event(&1, model))
            |> Enum.reject(&is_nil/1)

          {text_chunks, {rest, remaining}}
      end,
      fn _ -> :ok end
    )
  end

  defp build_websocket_replay_stream(
         chunks,
         %{wire_mod: wire_mod, protocol_mod: protocol_mod},
         model
       ) do
    Stream.resource(
      fn -> chunks end,
      fn
        [] ->
          {:halt, nil}

        [b64_chunk | rest] ->
          raw_data = Base.decode64!(b64_chunk)

          text_chunks =
            %{data: raw_data}
            |> wire_mod.decode_wire_event()
            |> Enum.flat_map(&protocol_mod.decode_event(&1, model))
            |> Enum.reject(&is_nil/1)

          {text_chunks, rest}
      end,
      fn _ -> :ok end
    )
  end

  defp build_framed_replay_stream(
         chunks,
         %{wire_mod: wire_mod, protocol_mod: protocol_mod},
         model
       ) do
    Stream.resource(
      fn -> chunks end,
      fn
        [] ->
          {:halt, nil}

        [b64_chunk | rest] ->
          raw_data = Base.decode64!(b64_chunk)

          framed_chunks =
            %{data: raw_data}
            |> wire_mod.decode_wire_event()
            |> Enum.flat_map(&protocol_mod.decode_event(&1, model))
            |> Enum.reject(&is_nil/1)

          {framed_chunks, rest}
      end,
      fn _ -> :ok end
    )
  end

  defp replay_runtime(fixture, model, opts) do
    fixture_runtime(fixture) || runtime_from_request(fixture, model) || runtime_from_opts(opts)
  end

  defp fixture_runtime(%{"execution" => execution}) when is_map(execution) do
    with {:ok, semantic_protocol} <- fetch_existing_atom(execution, "semantic_protocol"),
         {:ok, wire_format} <- fetch_existing_atom(execution, "wire_format") do
      %{
        protocol_mod: ExecutionModules.protocol_module!(semantic_protocol),
        wire_mod: ExecutionModules.wire_module!(wire_format)
      }
    else
      _ -> nil
    end
  end

  defp fixture_runtime(_fixture), do: nil

  defp runtime_from_opts(opts) do
    with semantic_protocol when is_atom(semantic_protocol) and not is_nil(semantic_protocol) <-
           Keyword.get(opts, :_execution_semantic_protocol),
         wire_format when is_atom(wire_format) and not is_nil(wire_format) <-
           Keyword.get(opts, :_execution_wire_format) do
      %{
        protocol_mod: ExecutionModules.protocol_module!(semantic_protocol),
        wire_mod: ExecutionModules.wire_module!(wire_format)
      }
    else
      _ -> nil
    end
  end

  defp runtime_from_request(%{"request" => %{"url" => url}}, model) when is_binary(url) do
    cond do
      String.contains?(url, "/v1/chat/completions") ->
        %{
          protocol_mod: ExecutionModules.protocol_module!(:openai_chat),
          wire_mod: ReqLlmNext.Wire.OpenAIChat
        }

      String.contains?(url, "/v1/responses") ->
        %{
          protocol_mod: ExecutionModules.protocol_module!(:openai_responses),
          wire_mod: ReqLlmNext.Wire.OpenAIResponses
        }

      String.contains?(url, "/v1/messages") ->
        %{
          protocol_mod: ExecutionModules.protocol_module!(:anthropic_messages),
          wire_mod: ReqLlmNext.Wire.Anthropic
        }

      true ->
        runtime_from_model(model)
    end
  end

  defp runtime_from_request(_fixture, model), do: runtime_from_model(model)

  @doc """
  Create a recorder struct to capture Finch stream data.
  """
  def start_recorder(model, fixture_name, prompt, request, execution \\ %{}) do
    %{
      model: model,
      fixture_name: fixture_name,
      prompt: prompt,
      request: extract_request_info(request),
      execution: normalize_execution_metadata(execution),
      status: nil,
      headers: %{},
      chunks: [],
      captured_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp extract_request_info(%Finch.Request{} = req) do
    body_binary = req.body || ""
    scheme = to_string(req.scheme)
    url = "#{scheme}://#{req.host}:#{req.port}#{req.path}"

    %{
      "method" => to_string(req.method) |> String.upcase(),
      "url" => url,
      "transport" => infer_transport(req),
      "headers" => redact_headers(req.headers),
      "body" => %{
        "b64" => Base.encode64(body_binary),
        "canonical_json" => safe_decode_json(body_binary)
      }
    }
  end

  defp extract_request_info(request) when is_map(request) do
    headers = Map.get(request, "headers") || Map.get(request, :headers) || []
    body = Map.get(request, "body") || Map.get(request, :body) || %{}

    %{
      "method" =>
        request
        |> Map.get("method", Map.get(request, :method, "WEBSOCKET"))
        |> to_string()
        |> String.upcase(),
      "url" => request |> Map.get("url", Map.get(request, :url)) |> to_string(),
      "transport" =>
        request
        |> Map.get("transport", Map.get(request, :transport, "websocket"))
        |> to_string(),
      "headers" => redact_headers(headers),
      "body" => normalize_body(body)
    }
  end

  defp infer_transport(%Finch.Request{} = req) do
    headers = Map.new(req.headers)

    case headers["Accept"] || headers["accept"] do
      "text/event-stream" -> "http_sse"
      _ -> "http"
    end
  end

  defp normalize_body(%{"b64" => _encoded, "canonical_json" => _json} = body), do: body

  defp normalize_body(%{b64: _encoded, canonical_json: _json} = body) do
    %{
      "b64" => body.b64,
      "canonical_json" => body.canonical_json
    }
  end

  defp normalize_body(binary) when is_binary(binary) do
    %{
      "b64" => Base.encode64(binary),
      "canonical_json" => safe_decode_json(binary)
    }
  end

  defp normalize_body(body) when is_map(body) do
    %{
      "b64" => body |> Jason.encode!() |> Base.encode64(),
      "canonical_json" => body
    }
  end

  defp redact_headers(headers) do
    headers
    |> normalize_headers()
    |> Enum.map(fn {k, v} ->
      key = String.downcase(to_string(k))

      value =
        if key in ["authorization", "x-api-key"] do
          "[REDACTED]"
        else
          v
        end

      {key, value}
    end)
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Map.new()
  end

  defp normalize_headers(headers) when is_map(headers), do: Map.to_list(headers)
  defp normalize_headers(headers) when is_list(headers), do: headers
  defp normalize_headers(_), do: []

  defp safe_decode_json(binary) do
    case Jason.decode(binary) do
      {:ok, json} -> json
      {:error, _} -> nil
    end
  end

  def record_status(nil, _status), do: nil
  def record_status(recorder, status), do: %{recorder | status: status}

  def record_headers(nil, _headers), do: nil

  def record_headers(recorder, headers) do
    header_map =
      headers
      |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Map.new()

    %{recorder | headers: header_map}
  end

  def record_chunk(nil, _data), do: nil

  def record_chunk(recorder, data) do
    %{recorder | chunks: [Base.encode64(data) | recorder.chunks]}
  end

  def save_fixture(nil), do: :ok

  def save_fixture(recorder) do
    fixture_path = path(recorder.model, recorder.fixture_name)
    File.mkdir_p!(Path.dirname(fixture_path))

    fixture = %{
      "provider" => Atom.to_string(recorder.model.provider),
      "model_id" => recorder.model.id,
      "prompt" => recorder.prompt,
      "captured_at" => recorder.captured_at,
      "request" => recorder.request,
      "execution" => Map.get(recorder, :execution, %{}),
      "response" => %{
        "status" => recorder.status,
        "headers" => recorder.headers
      },
      "chunks" => Enum.reverse(recorder.chunks)
    }

    File.write!(fixture_path, Jason.encode!(fixture, pretty: true))

    Telemetry.emit_fixture(
      :record,
      fixture_metadata(recorder.model, recorder.fixture_name, fixture)
    )

    :ok
  end

  @spec save_request_fixture(
          LLMDB.Model.t(),
          String.t(),
          Finch.Request.t(),
          map(),
          Finch.Response.t()
        ) ::
          :ok
  def save_request_fixture(
        %LLMDB.Model{} = model,
        fixture_name,
        %Finch.Request{} = request,
        execution,
        %Finch.Response{} = response
      ) do
    fixture_path = path(model, fixture_name)
    File.mkdir_p!(Path.dirname(fixture_path))

    fixture = %{
      "provider" => Atom.to_string(model.provider),
      "model_id" => model.id,
      "captured_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "request" => extract_request_info(request),
      "execution" => normalize_execution_metadata(execution),
      "response" => %{
        "status" => response.status,
        "headers" => redact_headers(response.headers),
        "body" => normalize_body(response.body)
      },
      "chunks" => []
    }

    File.write!(fixture_path, Jason.encode!(fixture, pretty: true))
    Telemetry.emit_fixture(:record, fixture_metadata(model, fixture_name, fixture))
    :ok
  end

  defp request_transport(%{"request" => %{"transport" => transport}}) when is_binary(transport),
    do: transport

  defp request_transport(_fixture), do: "http_sse"

  defp replay_request_fixture(%{"response" => response}, wire_mod, model, input, opts)
       when is_map(response) do
    status = Map.get(response, "status")
    headers = response |> Map.get("headers", %{}) |> normalize_headers()
    body = response |> Map.get("body", %{}) |> decode_replay_body()

    finch_response = %Finch.Response{status: status, headers: headers, body: body}

    decode_request_response(wire_mod, finch_response, model, input, opts)
  end

  defp replay_request_fixture(_fixture, _wire_mod, _model, _input, _opts), do: :no_fixture

  defp decode_request_response(wire_mod, %Finch.Response{} = response, model, input, opts) do
    if module_exports?(wire_mod, :decode_response, 4) do
      wire_mod.decode_response(response, model, input, opts)
    else
      default_decode_request_response(response)
    end
  end

  defp default_decode_request_response(%Finch.Response{body: response_body}) do
    case Jason.decode(response_body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, jason_error} ->
        {:error,
         ReqLlmNext.Error.API.JsonParse.exception(
           message: "Failed to parse HTTP response: #{Exception.message(jason_error)}",
           raw_json: response_body
         )}
    end
  end

  defp decode_replay_body(%{"b64" => encoded}) when is_binary(encoded),
    do: Base.decode64!(encoded)

  defp decode_replay_body(%{b64: encoded}) when is_binary(encoded), do: Base.decode64!(encoded)
  defp decode_replay_body(binary) when is_binary(binary), do: binary
  defp decode_replay_body(body) when is_map(body), do: Jason.encode!(body)
  defp decode_replay_body(_body), do: ""

  defp fixture_metadata(model, fixture_name, fixture) do
    Telemetry.fixture_metadata(model, fixture_name, %{
      fixture_transport: request_transport(fixture),
      surface_id: get_in(fixture, ["execution", "surface_id"]),
      semantic_protocol: get_in(fixture, ["execution", "semantic_protocol"]),
      wire_format: get_in(fixture, ["execution", "wire_format"]),
      transport: get_in(fixture, ["execution", "transport"])
    })
  end

  defp module_exports?(module, function_name, arity) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, function_name, arity)
  end

  defp runtime_from_model(model) do
    with {:ok, profile} <- ModelProfile.from_model(model),
         operation <- preferred_runtime_operation(profile),
         [%{semantic_protocol: semantic_protocol, wire_format: wire_format} | _] <-
           ModelProfile.surfaces_for(profile, operation) do
      %{
        protocol_mod: ExecutionModules.protocol_module!(semantic_protocol),
        wire_mod: ExecutionModules.wire_module!(wire_format)
      }
    else
      _ -> raise "Unable to determine replay runtime from model profile for #{inspect(model.id)}"
    end
  end

  defp preferred_runtime_operation(profile) do
    cond do
      ModelProfile.supports_operation?(profile, :text) -> :text
      ModelProfile.supports_operation?(profile, :object) -> :object
      ModelProfile.supports_operation?(profile, :embed) -> :embed
      true -> :text
    end
  end

  defp normalize_execution_metadata(execution) when is_map(execution) do
    execution
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map(fn {key, value} ->
      normalized =
        case value do
          atom when is_atom(atom) -> Atom.to_string(atom)
          other -> other
        end

      {Atom.to_string(key), normalized}
    end)
    |> Map.new()
  end

  defp fetch_existing_atom(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) ->
        try do
          {:ok, String.to_existing_atom(value)}
        rescue
          ArgumentError -> :error
        end

      value when is_atom(value) ->
        {:ok, value}

      _ ->
        :error
    end
  end
end
