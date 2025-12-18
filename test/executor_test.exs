defmodule ReqLlmNext.ExecutorTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Executor, Response}

  describe "generate_text/3" do
    test "returns text and model using fixture replay" do
      {:ok, result} = Executor.generate_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %Response{} = result
      text = Response.text(result)
      assert is_binary(text)
      assert String.length(text) > 0
      assert result.model.id == "gpt-4o-mini"
      assert result.model.provider == :openai
    end

    test "works with anthropic model" do
      {:ok, result} =
        Executor.generate_text("anthropic:claude-sonnet-4-20250514", "Hello!",
          fixture: "basic",
          max_tokens: 50
        )

      assert %Response{} = result
      assert is_binary(Response.text(result))
      assert result.model.provider == :anthropic
    end

    test "returns error for unknown model" do
      result = Executor.generate_text("openai:nonexistent-model", "Hello!", [])

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end
  end

  describe "stream_text/3" do
    test "returns StreamResponse with stream and model" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %ReqLlmNext.StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
      assert is_function(resp.stream) or is_struct(resp.stream, Stream)
    end

    test "stream can be enumerated" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      chunks = Enum.to_list(resp.stream)
      assert is_list(chunks)
      refute Enum.empty?(chunks)
      text_chunks = Enum.filter(chunks, &is_binary/1)
      assert length(text_chunks) > 0
    end

    test "returns error for unknown model" do
      result = Executor.stream_text("openai:nonexistent-model", "Hello!", [])

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end

    test "applies adapter pipeline for gpt-4o-mini" do
      {:ok, resp} =
        Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert resp.model.id == "gpt-4o-mini"
    end
  end

  describe "pipeline integration" do
    test "full pipeline flows through all steps" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o", "Test", fixture: "basic")

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
    end

    test "anthropic pipeline with max_tokens" do
      {:ok, resp} =
        Executor.stream_text("anthropic:claude-haiku-4-5-20251001", "Hello",
          fixture: "basic",
          max_tokens: 50
        )

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
    end

    test "passes temperature through adapter to wire" do
      {:ok, resp} =
        Executor.stream_text("openai:gpt-4o-mini", "Hello",
          fixture: "basic",
          temperature: 0.9
        )

      assert resp.model.id == "gpt-4o-mini"
    end
  end

  describe "error handling" do
    test "invalid model spec returns error" do
      result = Executor.stream_text("invalid:model", "Hello", [])
      assert {:error, _} = result
    end

    test "model not found returns descriptive error" do
      {:error, {:model_not_found, spec, _reason}} =
        Executor.stream_text("openai:not-a-real-model-xyz", "Hello", [])

      assert spec == "openai:not-a-real-model-xyz"
    end
  end

  describe "fixture replay" do
    test "replays openai fixture correctly" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
      assert String.length(text) > 0
    end

    test "replays anthropic fixture correctly" do
      {:ok, resp} =
        Executor.stream_text("anthropic:claude-sonnet-4-20250514", "Hello!",
          fixture: "basic",
          max_tokens: 50
        )

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
    end
  end
end
