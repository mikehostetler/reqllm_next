defmodule ReqLlmNext.Wire.ResolverTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Error, Providers}
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.{Anthropic, OpenAIChat, OpenAIEmbeddings, Resolver}

  describe "resolve!/1" do
    test "returns provider and wire module for OpenAI model" do
      model = TestModels.openai()
      result = Resolver.resolve!(model)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIChat
    end

    test "returns provider and wire module for Anthropic model" do
      model = TestModels.anthropic()
      result = Resolver.resolve!(model)

      assert result.provider_mod == Providers.Anthropic
      assert result.wire_mod == Anthropic
    end
  end

  describe "provider_module!/1" do
    test "returns OpenAI provider for OpenAI model" do
      model = TestModels.openai()
      assert Resolver.provider_module!(model) == Providers.OpenAI
    end

    test "returns Anthropic provider for Anthropic model" do
      model = TestModels.anthropic()
      assert Resolver.provider_module!(model) == Providers.Anthropic
    end

    test "raises for unknown provider" do
      model = TestModels.minimal(%{provider: :unknown_provider})

      assert_raise RuntimeError, ~r/Provider error/, fn ->
        Resolver.provider_module!(model)
      end
    end
  end

  describe "wire_module!/1" do
    test "infers OpenAIChat for openai provider" do
      model = TestModels.openai()
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for groq provider" do
      model = TestModels.groq()
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for openrouter provider" do
      model = TestModels.openrouter()
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers OpenAIChat for xai provider" do
      model = TestModels.xai()
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "infers Anthropic for anthropic provider" do
      model = TestModels.anthropic()
      assert Resolver.wire_module!(model) == Anthropic
    end

    test "defaults to OpenAIChat for unknown provider" do
      model = TestModels.minimal(%{provider: :some_other})
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "uses explicit wire protocol when specified as atom" do
      model = TestModels.openai(%{extra: %{wire: %{protocol: :anthropic}}})
      assert Resolver.wire_module!(model) == Anthropic
    end

    test "uses explicit wire protocol when specified as string" do
      model = TestModels.openai(%{extra: %{wire: %{protocol: "openai_chat"}}})
      assert Resolver.wire_module!(model) == OpenAIChat
    end

    test "raises for unknown explicit wire protocol" do
      model = TestModels.openai(%{extra: %{wire: %{protocol: :unknown_protocol}}})

      assert_raise RuntimeError, ~r/Unknown wire protocol/, fn ->
        Resolver.wire_module!(model)
      end
    end
  end

  describe "streaming_module!/1 (deprecated)" do
    @tag :capture_log
    test "delegates to wire_module!/1" do
      model = TestModels.openai()

      deprecated_result = apply(Resolver, :streaming_module!, [model])
      expected = Resolver.wire_module!(model)
      assert deprecated_result == expected
    end
  end

  describe "resolve!/2 with :embed operation" do
    test "returns OpenAI embeddings wire for OpenAI embedding model" do
      model = TestModels.openai_embedding()
      result = Resolver.resolve!(model, :embed)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIEmbeddings
    end

    test "raises for unsupported provider" do
      model = TestModels.anthropic()

      assert_raise Error.Invalid.Capability, ~r/does not support embeddings/, fn ->
        Resolver.resolve!(model, :embed)
      end
    end

    test "resolve!/2 with non-embed operation delegates to resolve!/1" do
      model = TestModels.openai()
      result = Resolver.resolve!(model, :text)

      assert result.provider_mod == Providers.OpenAI
      assert result.wire_mod == OpenAIChat
    end
  end
end
