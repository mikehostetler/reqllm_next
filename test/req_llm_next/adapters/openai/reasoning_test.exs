defmodule ReqLlmNext.Adapters.OpenAI.ReasoningTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Adapters.OpenAI.Reasoning

  describe "matches?/1" do
    test "matches models with api: responses in extra" do
      model = %LLMDB.Model{
        id: "some-custom-model",
        provider: :openai,
        extra: %{api: "responses"}
      }

      assert Reasoning.matches?(model)
    end

    test "matches o1 models by ID" do
      model = %LLMDB.Model{id: "o1", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "matches o1-preview models by ID" do
      model = %LLMDB.Model{id: "o1-preview", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "matches o1-mini models by ID" do
      model = %LLMDB.Model{id: "o1-mini", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "matches o3 models by ID" do
      model = %LLMDB.Model{id: "o3", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "matches o3-mini models by ID" do
      model = %LLMDB.Model{id: "o3-mini", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "matches o4 models by ID" do
      model = %LLMDB.Model{id: "o4", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "matches gpt-5 models by ID" do
      model = %LLMDB.Model{id: "gpt-5", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "matches gpt-5-preview models by ID" do
      model = %LLMDB.Model{id: "gpt-5-preview", provider: :openai}
      assert Reasoning.matches?(model)
    end

    test "does not match Chat API models" do
      model = %LLMDB.Model{id: "gpt-4o", provider: :openai}
      refute Reasoning.matches?(model)
    end

    test "does not match gpt-4o-mini" do
      model = %LLMDB.Model{id: "gpt-4o-mini", provider: :openai}
      refute Reasoning.matches?(model)
    end

    test "does not match non-OpenAI providers" do
      model = %LLMDB.Model{id: "claude-3-opus", provider: :anthropic}
      refute Reasoning.matches?(model)
    end
  end

  describe "transform_opts/2" do
    test "sets default max_completion_tokens" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, [])

      assert opts[:max_completion_tokens] == 16_000
    end

    test "sets thinking timeout" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, [])

      assert opts[:receive_timeout] == 300_000
    end

    test "preserves existing max_completion_tokens" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, max_completion_tokens: 32_000)

      assert opts[:max_completion_tokens] == 32_000
    end

    test "normalizes max_tokens to max_completion_tokens" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, max_tokens: 8000)

      assert opts[:max_completion_tokens] == 8000
      refute Keyword.has_key?(opts, :max_tokens)
    end

    test "normalizes max_output_tokens to max_completion_tokens" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, max_output_tokens: 4000)

      assert opts[:max_completion_tokens] == 4000
    end

    test "removes temperature (not supported by reasoning models)" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, temperature: 0.7)

      refute Keyword.has_key?(opts, :temperature)
    end

    test "preserves other options" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, reasoning_effort: :high, custom_opt: "value")

      assert opts[:reasoning_effort] == :high
      assert opts[:custom_opt] == "value"
    end

    test "marks adapter as applied" do
      model = reasoning_model()
      opts = Reasoning.transform_opts(model, [])

      assert opts[:_adapter_applied] == Reasoning
    end
  end

  defp reasoning_model do
    %LLMDB.Model{
      id: "o1",
      provider: :openai,
      extra: %{api: "responses"}
    }
  end
end
