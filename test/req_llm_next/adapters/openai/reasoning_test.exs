defmodule ReqLlmNext.Adapters.OpenAI.ReasoningTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Adapters.OpenAI.Reasoning
  alias ReqLlmNext.TestModels

  describe "matches?/1" do
    test "matches models with api: responses in extra" do
      model = TestModels.openai(%{id: "some-custom-model", extra: %{api: "responses"}})
      assert Reasoning.matches?(model)
    end

    test "matches models with wire.protocol: openai_responses in extra" do
      model =
        TestModels.openai(%{
          id: "some-custom-model",
          extra: %{wire: %{protocol: :openai_responses}}
        })

      assert Reasoning.matches?(model)
    end

    test "matches reasoning models from factory (has wire.protocol metadata)" do
      model = TestModels.openai_reasoning(%{id: "o1"})
      assert Reasoning.matches?(model)
    end

    test "does not match Chat API models without metadata" do
      model = TestModels.openai(%{id: "gpt-4o"})
      refute Reasoning.matches?(model)
    end

    test "does not match gpt-4o-mini" do
      model = TestModels.openai(%{id: "gpt-4o-mini"})
      refute Reasoning.matches?(model)
    end

    test "does not match non-OpenAI providers" do
      model = TestModels.anthropic(%{id: "claude-3-opus"})
      refute Reasoning.matches?(model)
    end

    test "does not match by model ID prefix alone (no heuristics)" do
      model = TestModels.openai(%{id: "o1-fake"})
      refute Reasoning.matches?(model)
    end
  end

  describe "transform_opts/2" do
    test "sets default max_completion_tokens" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, [])

      assert opts[:max_completion_tokens] == 16_000
    end

    test "sets thinking timeout" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, [])

      assert opts[:receive_timeout] == 300_000
    end

    test "preserves existing max_completion_tokens" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, max_completion_tokens: 32_000)

      assert opts[:max_completion_tokens] == 32_000
    end

    test "normalizes max_tokens to max_completion_tokens" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, max_tokens: 8000)

      assert opts[:max_completion_tokens] == 8000
      refute Keyword.has_key?(opts, :max_tokens)
    end

    test "normalizes max_output_tokens to max_completion_tokens" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, max_output_tokens: 4000)

      assert opts[:max_completion_tokens] == 4000
    end

    test "removes temperature (not supported by reasoning models)" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, temperature: 0.7)

      refute Keyword.has_key?(opts, :temperature)
    end

    test "preserves other options" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, reasoning_effort: :high, custom_opt: "value")

      assert opts[:reasoning_effort] == :high
      assert opts[:custom_opt] == "value"
    end

    test "marks adapter as applied" do
      model = TestModels.openai_reasoning()
      opts = Reasoning.transform_opts(model, [])

      assert opts[:_adapter_applied] == Reasoning
    end
  end
end
