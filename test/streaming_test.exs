defmodule ReqLlmNext.StreamingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.StreamResponse

  describe "stream_text/3 OpenAI" do
    test "gpt-4o-mini streaming" do
      {:ok, %{stream: stream, model: model}} =
        ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      chunks = Enum.to_list(stream)
      assert chunks != []
      text = StreamResponse.text(%StreamResponse{stream: chunks, model: model})
      assert String.length(text) > 0
      assert model.provider == :openai
    end

    test "gpt-4o streaming" do
      {:ok, resp} =
        ReqLlmNext.stream_text("openai:gpt-4o", "Say hello briefly", fixture: "basic")

      text = StreamResponse.text(resp)
      assert String.contains?(text, "Hello")
      assert resp.model.id == "gpt-4o"
    end
  end

  describe "stream_text/3 Anthropic" do
    test "claude-sonnet-4 streaming" do
      {:ok, resp} =
        ReqLlmNext.stream_text("anthropic:claude-sonnet-4-20250514", "Say hello briefly",
          fixture: "basic",
          max_tokens: 50
        )

      text = StreamResponse.text(resp)
      assert String.contains?(text, "Hello")
      assert resp.model.provider == :anthropic
    end

    test "claude-haiku-4.5 streaming" do
      {:ok, resp} =
        ReqLlmNext.stream_text("anthropic:claude-haiku-4-5-20251001", "Say hello briefly",
          fixture: "basic",
          max_tokens: 50
        )

      text = StreamResponse.text(resp)
      assert String.length(text) > 0
      assert resp.model.provider == :anthropic
    end
  end
end
