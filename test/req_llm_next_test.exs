defmodule ReqLlmNextTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context

  describe "put_key/2 and get_key/1" do
    test "stores and retrieves atom keys from application config" do
      assert :ok = ReqLlmNext.put_key(:test_api_key, "test-value-123")
      assert ReqLlmNext.get_key(:test_api_key) == "test-value-123"
    end

    test "get_key/1 with string key reads from environment" do
      System.put_env("REQ_LLM_NEXT_TEST_KEY", "env-value")
      assert ReqLlmNext.get_key("REQ_LLM_NEXT_TEST_KEY") == "env-value"
      System.delete_env("REQ_LLM_NEXT_TEST_KEY")
    end

    test "get_key/1 returns nil for missing keys" do
      assert ReqLlmNext.get_key(:nonexistent_key_12345) == nil
    end

    test "put_key/2 raises for non-atom keys" do
      assert_raise ArgumentError, ~r/expects an atom key/, fn ->
        ReqLlmNext.put_key("string_key", "value")
      end
    end
  end

  describe "context/1" do
    test "creates context from string prompt" do
      ctx = ReqLlmNext.context("Hello!")

      assert %Context{} = ctx
      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end

    test "creates context from message list" do
      messages = [
        Context.system("You are helpful"),
        Context.user("Hello!")
      ]

      ctx = ReqLlmNext.context(messages)

      assert length(ctx.messages) == 2
      assert Enum.at(ctx.messages, 0).role == :system
      assert Enum.at(ctx.messages, 1).role == :user
    end

    test "creates context from single message" do
      msg = Context.user("Hello!")
      ctx = ReqLlmNext.context(msg)

      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end
  end

  describe "provider/1" do
    test "returns known provider module" do
      assert {:ok, ReqLlmNext.Providers.OpenAI} = ReqLlmNext.provider(:openai)
      assert {:ok, ReqLlmNext.Providers.Anthropic} = ReqLlmNext.provider(:anthropic)
    end

    test "returns error for unknown provider" do
      assert {:error, {:unknown_provider, :unknown_provider}} =
               ReqLlmNext.provider(:unknown_provider)
    end
  end

  describe "model/1" do
    test "resolves string model spec" do
      assert {:ok, model} = ReqLlmNext.model("openai:gpt-4o-mini")
      assert model.provider == :openai
      assert model.id == "gpt-4o-mini"
    end

    test "passes through LLMDB.Model struct" do
      {:ok, original} = LLMDB.model("openai:gpt-4o")
      assert {:ok, ^original} = ReqLlmNext.model(original)
    end

    test "resolves tuple format with options" do
      assert {:ok, model} = ReqLlmNext.model({:openai, "gpt-4o-mini", temperature: 0.7})
      assert model.provider == :openai
      assert model.id == "gpt-4o-mini"
    end

    test "resolves tuple format with keyword list" do
      assert {:ok, model} = ReqLlmNext.model({:openai, id: "gpt-4o-mini"})
      assert model.provider == :openai
    end

    test "returns error for invalid spec" do
      assert {:error, _} = ReqLlmNext.model(:invalid)
    end
  end

  describe "generate_text/3" do
    test "returns Response struct using buffered stream with fixture" do
      {:ok, result} =
        ReqLlmNext.generate_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %ReqLlmNext.Response{} = result
      text = ReqLlmNext.Response.text(result)
      assert String.length(text) > 0
      assert result.model.id == "gpt-4o-mini"
    end

    test "delegates to Executor" do
      {:ok, result} = ReqLlmNext.generate_text("openai:gpt-4o", "Test", fixture: "basic")

      assert %ReqLlmNext.Response{} = result
      assert is_binary(ReqLlmNext.Response.text(result))
      assert result.model.provider == :openai
    end
  end

  describe "stream_text/3" do
    test "returns StreamResponse" do
      {:ok, resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %ReqLlmNext.StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
    end

    test "stream produces text chunks" do
      {:ok, resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      chunks = Enum.to_list(resp.stream)
      refute Enum.empty?(chunks)
    end

    test "works with anthropic" do
      {:ok, resp} =
        ReqLlmNext.stream_text("anthropic:claude-sonnet-4-20250514", "Hello!",
          fixture: "basic",
          max_tokens: 50
        )

      assert resp.model.provider == :anthropic
    end
  end
end
