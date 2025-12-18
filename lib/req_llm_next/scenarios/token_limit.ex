defmodule ReqLlmNext.Scenarios.TokenLimit do
  @moduledoc """
  Token limit constraint scenario.

  Tests that max_tokens constraints are properly respected.
  """

  use ReqLlmNext.Scenario,
    id: :token_limit,
    name: "Token Limit",
    description: "Token limit constraint handling"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.chat?(model)

  @impl true
  def run(model_spec, _model, opts) do
    fixture_opts = Keyword.merge(opts, fixture: fixture_name(id()), max_tokens: 50)

    case ReqLlmNext.generate_text(
           model_spec,
           "Write a very long story about dragons and adventures.",
           fixture_opts
         ) do
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
            word_count = text |> String.split() |> length()

            if word_count <= 100 do
              ok([step("generate_text", :ok, response: response)])
            else
              error({:token_limit_exceeded, word_count}, [
                step("generate_text", :error,
                  response: response,
                  error: {:token_limit_exceeded, word_count}
                )
              ])
            end
        end

      {:error, reason} ->
        error(reason, [step("generate_text", :error, error: reason)])
    end
  end
end
