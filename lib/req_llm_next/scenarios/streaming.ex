defmodule ReqLlmNext.Scenarios.Streaming do
  @moduledoc """
  Streaming text generation scenario.

  Tests SSE parsing and Finch streaming path with system context.
  """

  use ReqLlmNext.Scenario,
    id: :streaming,
    name: "Streaming",
    description: "SSE parsing and Finch streaming path"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model) do
    ModelHelpers.chat?(model) and ModelHelpers.streaming_text?(model)
  end

  @impl true
  def run(model_spec, _model, opts) do
    context =
      ReqLlmNext.context([
        ReqLlmNext.Context.system("You are a helpful assistant."),
        ReqLlmNext.Context.user("Say hello in one short sentence.")
      ])

    fixture_opts = Keyword.merge(opts, fixture: fixture_name(id()), max_tokens: 100)

    case ReqLlmNext.stream_text(model_spec, context, fixture_opts) do
      {:ok, stream_resp} ->
        text = ReqLlmNext.StreamResponse.text(stream_resp)

        cond do
          not is_binary(text) ->
            error(:invalid_text_type, [
              step("stream_text", :error, response: stream_resp, error: :invalid_text_type)
            ])

          String.length(text) == 0 ->
            error(:empty_response, [
              step("stream_text", :error, response: stream_resp, error: :empty_response)
            ])

          true ->
            ok([step("stream_text", :ok, response: stream_resp)])
        end

      {:error, reason} ->
        error(reason, [step("stream_text", :error, error: reason)])
    end
  end
end
