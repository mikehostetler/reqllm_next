defmodule ReqLlmNext.ProviderTest.Comprehensive do
  @moduledoc """
  Comprehensive per-model provider tests for ReqLlmNext v2.

  Uses the scenario system to generate tests based on model capabilities.
  Each scenario determines its own applicability and runs its own tests.

  Tests use fixtures for fast, deterministic execution while supporting
  live API recording with REQ_LLM_NEXT_FIXTURES_MODE=record.

  ## Usage

      defmodule ReqLlmNext.Coverage.OpenAI.ComprehensiveTest do
        use ReqLlmNext.ProviderTest.Comprehensive,
          provider: :openai,
          models: ["openai:gpt-4o-mini", "openai:gpt-4o"]
      end

  """

  @doc """
  Returns list of models for a provider.
  """
  def models_for_provider(:openai) do
    [
      "openai:gpt-4o-mini",
      "openai:gpt-4o"
    ]
  end

  def models_for_provider(:anthropic) do
    [
      "anthropic:claude-sonnet-4-20250514",
      "anthropic:claude-haiku-4-5-20251001"
    ]
  end

  def models_for_provider(_), do: []

  defmacro __using__(opts) do
    provider = Keyword.fetch!(opts, :provider)
    models = Keyword.get(opts, :models)

    quote bind_quoted: [provider: provider, models: models] do
      use ExUnit.Case, async: false

      import ExUnit.Case

      @moduletag :coverage
      @moduletag provider: to_string(provider)
      @moduletag timeout: 300_000

      @provider provider
      @models models || ReqLlmNext.ProviderTest.Comprehensive.models_for_provider(provider)

      setup_all do
        LLMDB.load(allow: :all, custom: %{})
        :ok
      end

      for model_spec <- @models do
        @model_spec model_spec

        describe "#{model_spec}" do
          @describetag model: model_spec |> String.split(":", parts: 2) |> List.last()

          {:ok, model} = LLMDB.model(model_spec)
          scenarios = ReqLlmNext.Scenarios.for_model(model)

          for scenario_mod <- scenarios do
            @scenario_mod scenario_mod
            @tag scenario: scenario_mod.id()

            test scenario_mod.name() do
              {:ok, model} = LLMDB.model(unquote(model_spec))
              result = unquote(scenario_mod).run(unquote(model_spec), model, [])

              assert result.status == :ok,
                     """
                     Scenario :#{unquote(scenario_mod).id()} failed for #{unquote(model_spec)}

                     Error: #{inspect(result.error)}

                     Steps: #{inspect(result.steps, pretty: true)}
                     """
            end
          end
        end
      end
    end
  end
end
