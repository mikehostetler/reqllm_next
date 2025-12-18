defmodule ReqLlmNext.Scenarios.Usage do
  @moduledoc """
  Usage metrics scenario.

  Tests that token usage data is properly extracted and returned.
  """

  use ReqLlmNext.Scenario,
    id: :usage,
    name: "Usage Metrics",
    description: "Token usage data extraction"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.chat?(model)

  @impl true
  def run(model_spec, _model, opts) do
    fixture_opts = Keyword.merge(opts, fixture: fixture_name(id()), max_tokens: 20)

    case ReqLlmNext.stream_text(model_spec, "Hi there!", fixture_opts) do
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
