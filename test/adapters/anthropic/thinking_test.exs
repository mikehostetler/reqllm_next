defmodule ReqLlmNext.Adapters.Anthropic.ThinkingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Adapters.Anthropic.Thinking

  describe "matches?/1" do
    test "matches Anthropic models" do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      assert Thinking.matches?(model)
    end

    test "matches any Anthropic model" do
      model = %LLMDB.Model{id: "claude-3-haiku-20240307", provider: :anthropic}
      assert Thinking.matches?(model)
    end

    test "does not match OpenAI models" do
      model = %LLMDB.Model{id: "gpt-4o", provider: :openai}
      refute Thinking.matches?(model)
    end

    test "does not match Google models" do
      model = %LLMDB.Model{id: "gemini-1.5-pro", provider: :google}
      refute Thinking.matches?(model)
    end
  end

  describe "transform_opts/2 when thinking enabled" do
    setup do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      {:ok, model: model}
    end

    test "sets extended timeout", %{model: model} do
      opts = [thinking: %{type: "enabled", budget_tokens: 4096}]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :receive_timeout) == 300_000
    end

    test "removes temperature", %{model: model} do
      opts = [thinking: %{type: "enabled"}, temperature: 0.7]
      result = Thinking.transform_opts(model, opts)

      refute Keyword.has_key?(result, :temperature)
    end

    test "removes top_k", %{model: model} do
      opts = [thinking: %{type: "enabled"}, top_k: 40]
      result = Thinking.transform_opts(model, opts)

      refute Keyword.has_key?(result, :top_k)
    end

    test "adjusts top_p below minimum to 0.95", %{model: model} do
      opts = [thinking: %{type: "enabled"}, top_p: 0.5]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :top_p) == 0.95
    end

    test "adjusts top_p above maximum to 1.0", %{model: model} do
      opts = [thinking: %{type: "enabled"}, top_p: 1.5]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :top_p) == 1.0
    end

    test "preserves valid top_p values", %{model: model} do
      opts = [thinking: %{type: "enabled"}, top_p: 0.98]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :top_p) == 0.98
    end

    test "adjusts max_tokens when less than budget", %{model: model} do
      opts = [thinking: %{type: "enabled", budget_tokens: 4096}, max_tokens: 1000]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :max_tokens) == 4097 + 200
    end

    test "preserves max_tokens when greater than budget", %{model: model} do
      opts = [thinking: %{type: "enabled", budget_tokens: 2048}, max_tokens: 8000]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :max_tokens) == 8000
    end

    test "marks adapter as applied", %{model: model} do
      opts = [thinking: %{type: "enabled"}]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :_adapter_applied) == Thinking
    end
  end

  describe "transform_opts/2 when reasoning_effort set" do
    setup do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      {:ok, model: model}
    end

    test "sets timeout for reasoning_effort", %{model: model} do
      opts = [reasoning_effort: :medium]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :receive_timeout) == 300_000
    end

    test "removes temperature for reasoning_effort", %{model: model} do
      opts = [reasoning_effort: :high, temperature: 0.5]
      result = Thinking.transform_opts(model, opts)

      refute Keyword.has_key?(result, :temperature)
    end

    test "adjusts max_tokens based on effort level", %{model: model} do
      opts = [reasoning_effort: :high, max_tokens: 1000]
      result = Thinking.transform_opts(model, opts)

      assert Keyword.get(result, :max_tokens) == 4096 + 201
    end
  end

  describe "transform_opts/2 when thinking disabled" do
    setup do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      {:ok, model: model}
    end

    test "preserves all opts unchanged", %{model: model} do
      opts = [temperature: 0.7, max_tokens: 1024, top_p: 0.9, top_k: 40]
      result = Thinking.transform_opts(model, opts)

      assert result == opts
    end

    test "does not add timeout", %{model: model} do
      opts = [temperature: 0.7]
      result = Thinking.transform_opts(model, opts)

      refute Keyword.has_key?(result, :receive_timeout)
    end

    test "does not mark adapter as applied", %{model: model} do
      opts = []
      result = Thinking.transform_opts(model, opts)

      refute Keyword.has_key?(result, :_adapter_applied)
    end
  end
end
