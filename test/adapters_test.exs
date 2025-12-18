defmodule ReqLlmNext.AdaptersTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Adapters.OpenAI.GPT4oMini
  alias ReqLlmNext.Adapters.Pipeline

  describe "Pipeline.adapters_for/1" do
    test "finds gpt-4o-mini adapter" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      adapters = Pipeline.adapters_for(model)
      assert GPT4oMini in adapters
    end

    test "returns empty list for models without adapters" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      adapters = Pipeline.adapters_for(model)
      assert adapters == []
    end

    test "returns thinking adapter for anthropic models" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      adapters = Pipeline.adapters_for(model)
      assert ReqLlmNext.Adapters.Anthropic.Thinking in adapters
    end
  end

  describe "Pipeline.apply/2" do
    test "applies gpt-4o-mini adapter transforms" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      opts = [max_tokens: 100]

      result = Pipeline.apply(model, opts)

      assert result[:max_tokens] == 100
      assert result[:temperature] == 0.7
      assert result[:_adapter_applied] == GPT4oMini
    end

    test "does not override existing temperature" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      opts = [temperature: 0.5]

      result = Pipeline.apply(model, opts)

      assert result[:temperature] == 0.5
      assert result[:_adapter_applied] == GPT4oMini
    end

    test "passes through opts unchanged for models without adapters" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      opts = [max_tokens: 100]

      result = Pipeline.apply(model, opts)

      assert result == opts
    end
  end

  describe "GPT4oMini adapter" do
    test "matches gpt-4o-mini" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      assert GPT4oMini.matches?(model)
    end

    test "does not match gpt-4o" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      refute GPT4oMini.matches?(model)
    end
  end

  describe "integration - adapter affects wire encoding" do
    alias ReqLlmNext.Wire.OpenAIChat

    test "gpt-4o-mini gets default temperature in encoded body" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      opts = [max_tokens: 100]
      adapted_opts = Pipeline.apply(model, opts)

      body = OpenAIChat.encode_body(model, "hello", adapted_opts)

      assert body.temperature == 0.7
      assert body.max_tokens == 100
    end

    test "gpt-4o does not get default temperature" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      opts = [max_tokens: 100]
      adapted_opts = Pipeline.apply(model, opts)

      body = OpenAIChat.encode_body(model, "hello", adapted_opts)

      refute Map.has_key?(body, :temperature)
      assert body.max_tokens == 100
    end
  end
end
