defmodule ReqLlmNext.Scenarios.MultiTurn do
  @moduledoc """
  Multi-turn conversation scenario.

  Tests that the client correctly handles multi-message context and that
  the model can reference information from earlier turns.
  """

  use ReqLlmNext.Scenario,
    id: :multi_turn,
    name: "Multi-turn Context",
    description: "Conversational memory and context handling"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.chat?(model)

  @impl true
  def run(model_spec, _model, opts) do
    turn1_opts = Keyword.merge(opts, fixture: fixture_name(id(), "1"), max_tokens: 50)

    turn1_prompt =
      "I will tell you a secret word. Just reply with 'ACK' and nothing else. Secret word: BANANA"

    case ReqLlmNext.generate_text(model_spec, turn1_prompt, turn1_opts) do
      {:ok, response1} ->
        text1 = ReqLlmNext.Response.text(response1) || ""

        if String.length(text1) == 0 do
          error(:empty_turn1_response, [
            step("turn_1", :error, response: response1, error: :empty_turn1_response)
          ])
        else
          run_turn2(model_spec, response1, opts)
        end

      {:error, reason} ->
        error(reason, [step("turn_1", :error, error: reason)])
    end
  end

  defp run_turn2(model_spec, response1, opts) do
    context =
      ReqLlmNext.Context.append(
        response1.context,
        ReqLlmNext.Context.user(
          "What was the secret word I told you earlier? Answer with only the word, nothing else."
        )
      )

    turn2_opts = Keyword.merge(opts, fixture: fixture_name(id(), "2"), max_tokens: 50)

    case ReqLlmNext.generate_text(model_spec, context, turn2_opts) do
      {:ok, response2} ->
        text2 = ReqLlmNext.Response.text(response2) || ""
        normalized = text2 |> String.trim() |> String.upcase()

        if String.contains?(normalized, "BANANA") do
          ok([
            step("turn_1", :ok, response: response1),
            step("turn_2", :ok, response: response2)
          ])
        else
          error({:wrong_secret_word, text2}, [
            step("turn_1", :ok, response: response1),
            step("turn_2", :error, response: response2, error: {:wrong_secret_word, text2})
          ])
        end

      {:error, reason} ->
        error(reason, [
          step("turn_1", :ok, response: response1),
          step("turn_2", :error, error: reason)
        ])
    end
  end
end
