defmodule ReqLlmNext.Wire.ResolverTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Error, Providers}
  alias ReqLlmNext.Wire.{Anthropic, OpenAIChat, OpenAIEmbeddings, Resolver}

  describe "resolve!/1" do
    test "returns provider and wire module for OpenAI model" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Resolver.resolve!(model)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIChat
    end

    test "returns provider and wire module for Anthropic model" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Resolver.resolve!(model)

      assert result.provider_mod == Providers.Anthropic
      assert result.wire_mod == Anthropic
    end
  end

  describe "provider_module!/1" do
    test "returns OpenAI provider for OpenAI model" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      assert Resolver.provider_module!(model) == Providers.OpenAI
    end

    test "returns Anthropic provider for Anthropic model" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      assert Resolver.provider_module!(model) == Providers.Anthropic
    end

    test "raises for unknown provider" do
      model = %LLMDB.Model{id: "test", provider: :unknown_provider}

      assert_raise RuntimeError, ~r/Provider error/, fn ->
        Resolver.provider_module!(model)
      end
    end
  end

  describe "wire_module!/1" do
    test "infers OpenAIChat for openai provider" do
      model = %LLMDB.Model{id: "test", provider: :openai}
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for groq provider" do
      model = %LLMDB.Model{id: "test", provider: :groq}
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for openrouter provider" do
      model = %LLMDB.Model{id: "test", provider: :openrouter}
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for xai provider" do
      model = %LLMDB.Model{id: "test", provider: :xai}
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers Anthropic for anthropic provider" do
      model = %LLMDB.Model{id: "test", provider: :anthropic}
      assert Resolver.wire_module!(model) == Anthropic
    end

    test "defaults to OpenAIChat for unknown provider" do
      model = %LLMDB.Model{id: "test", provider: :some_other}
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "uses explicit wire protocol when specified as atom" do
      model = %LLMDB.Model{
        id: "test",
        provider: :openai,
        extra: %{wire: %{protocol: :anthropic}}
      }

      assert Resolver.wire_module!(model) == Anthropic
    end

    test "uses explicit wire protocol when specified as string" do
      model = %LLMDB.Model{
        id: "test",
        provider: :openai,
        extra: %{wire: %{protocol: "openai_chat"}}
      }

      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "raises for unknown explicit wire protocol" do
      model = %LLMDB.Model{
        id: "test",
        provider: :openai,
        extra: %{wire: %{protocol: :unknown_protocol}}
      }

      assert_raise RuntimeError, ~r/Unknown wire protocol/, fn ->
        Resolver.wire_module!(model)
      end
    end
  end

  describe "streaming_module!/1 (deprecated)" do
    @tag :capture_log
    test "delegates to wire_module!/1" do
      model = %LLMDB.Model{id: "test", provider: :openai}

      # Call the deprecated function - warning is expected and acceptable
      # since we're explicitly testing the deprecated API still works
      deprecated_result = apply(Resolver, :streaming_module!, [model])
      expected = Resolver.wire_module!(model)
      assert deprecated_result == expected
    end
  end

  describe "resolve!/2 with :embed operation" do
    test "returns OpenAI embeddings wire for OpenAI model" do
      {:ok, model} = LLMDB.model("openai:text-embedding-3-small")
      result = Resolver.resolve!(model, :embed)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIEmbeddings
    end

    test "raises for unsupported provider" do
      model = %LLMDB.Model{id: "test", provider: :anthropic}

      assert_raise Error.Invalid.Capability, ~r/does not support embeddings/, fn ->
        Resolver.resolve!(model, :embed)
      end
    end

    test "resolve!/2 with non-embed operation delegates to resolve!/1" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Resolver.resolve!(model, :text)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIChat
    end
  end
end
