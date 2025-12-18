defmodule ReqLlmNext.Scenarios.Basic do
  @moduledoc """
  Basic text generation scenario.

  Tests that the pipeline works at all for chat models.
  Uses non-streaming generate_text to verify end-to-end functionality.
  """

  use ReqLlmNext.Scenario,
    id: :basic,
    name: "Basic Text",
    description: "Pipeline works at all for chat models"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.chat?(model)

  @impl true
  def run(model_spec, _model, opts) do
    fixture_opts = Keyword.merge(opts, fixture: fixture_name(id()), max_tokens: 100)

    case ReqLlmNext.generate_text(model_spec, "Hello world! Respond briefly.", fixture_opts) do
      {:ok, response} ->
        text = ReqLlmNext.Response.text(response)

        cond do
          not is_binary(text) ->
            error(:invalid_text_type, [
              step("generate_text", :error, response: response, error: :invalid_text_type)
            ])

          String.length(text) == 0 ->
            error(:empty_response, [
              step("generate_text", :error, response: response, error: :empty_response)
            ])

          true ->
            ok([step("generate_text", :ok, response: response)])
        end

      {:error, reason} ->
        error(reason, [step("generate_text", :error, error: reason)])
    end
  end
end
