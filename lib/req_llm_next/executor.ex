defmodule ReqLlmNext.Executor do
  @moduledoc """
  Central pipeline orchestration for ReqLLM v2.

  Tracer bullet implementation - handles only gpt-4o-mini streaming for now.
  """

  alias ReqLlmNext.{ModelResolver, Wire, StreamResponse}

  @spec stream_text(String.t(), String.t(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_text(model_spec, prompt, opts \\ []) do
    with {:ok, model} <- ModelResolver.resolve(model_spec),
         {:ok, finch_request} <- build_stream_request(model, prompt, opts),
         {:ok, stream} <- start_stream(finch_request, model) do
      {:ok, %StreamResponse{stream: stream, model: model}}
    end
  end

  defp build_stream_request(model, prompt, opts) do
    Wire.OpenAIChat.build_stream_request(model, prompt, opts)
  end

  defp start_stream(finch_request, model) do
    stream =
      Stream.resource(
        fn -> start_finch_stream(finch_request) end,
        fn state -> next_chunk(state, model) end,
        fn state -> cleanup(state) end
      )

    {:ok, stream}
  end

  defp start_finch_stream(finch_request) do
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
      buffer: ""
    }
  end

  defp next_chunk(%{ref: ref, buffer: buffer} = state, model) do
    receive do
      {^ref, :status, status} when status != 200 ->
        {:halt, Map.put(state, :error, {:http_error, status})}

      {^ref, :status, _status} ->
        next_chunk(state, model)

      {^ref, :headers, _headers} ->
        next_chunk(state, model)

      {^ref, :data, data} ->
        new_buffer = buffer <> data
        {events, remaining} = ServerSentEvents.parse(new_buffer)

        chunks =
          events
          |> Enum.flat_map(&decode_event(&1, model))
          |> Enum.reject(&is_nil/1)

        new_state = %{state | buffer: remaining}

        case chunks do
          [] -> next_chunk(new_state, model)
          chunks -> {chunks, new_state}
        end

      {^ref, :done} ->
        {:halt, state}
    after
      30_000 ->
        {:halt, Map.put(state, :error, :timeout)}
    end
  end

  defp decode_event(%{data: "[DONE]"}, _model), do: [nil]

  defp decode_event(%{data: data}, _model) do
    case Jason.decode(data) do
      {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}}
      when is_binary(content) ->
        [content]

      {:ok, _} ->
        []

      {:error, _} ->
        []
    end
  end

  defp cleanup(%{task: task}) do
    Task.shutdown(task, :brutal_kill)
    :ok
  end
end
