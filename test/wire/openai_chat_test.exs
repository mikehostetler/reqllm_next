defmodule ReqLlmNext.Wire.OpenAIChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Wire.OpenAIChat

  describe "endpoint/0" do
    test "returns chat completions endpoint" do
      assert OpenAIChat.endpoint() == "/chat/completions"
    end
  end

  describe "encode_body/3" do
    test "encodes basic prompt" do
      model = %LLMDB.Model{id: "gpt-4o-mini", provider: :openai}
      body = OpenAIChat.encode_body(model, "Hello!", [])

      assert body.model == "gpt-4o-mini"
      assert body.messages == [%{role: "user", content: "Hello!"}]
      assert body.stream == true
      assert body.stream_options == %{include_usage: true}
    end

    test "includes max_tokens when provided" do
      model = %LLMDB.Model{id: "gpt-4o", provider: :openai}
      body = OpenAIChat.encode_body(model, "Hello!", max_tokens: 100)

      assert body.max_tokens == 100
    end

    test "includes temperature when provided" do
      model = %LLMDB.Model{id: "gpt-4o", provider: :openai}
      body = OpenAIChat.encode_body(model, "Hello!", temperature: 0.5)

      assert body.temperature == 0.5
    end

    test "includes both max_tokens and temperature" do
      model = %LLMDB.Model{id: "gpt-4o", provider: :openai}
      body = OpenAIChat.encode_body(model, "Hello!", max_tokens: 200, temperature: 0.8)

      assert body.max_tokens == 200
      assert body.temperature == 0.8
    end

    test "omits nil values" do
      model = %LLMDB.Model{id: "gpt-4o", provider: :openai}
      body = OpenAIChat.encode_body(model, "Hello!", [])

      refute Map.has_key?(body, :max_tokens)
      refute Map.has_key?(body, :temperature)
    end
  end

  describe "options_schema/0" do
    test "returns valid NimbleOptions-style schema" do
      schema = OpenAIChat.options_schema()

      assert Keyword.has_key?(schema, :max_tokens)
      assert Keyword.has_key?(schema, :temperature)
      assert Keyword.has_key?(schema, :top_p)
      assert Keyword.has_key?(schema, :frequency_penalty)
      assert Keyword.has_key?(schema, :presence_penalty)
    end
  end

  describe "decode_sse_event/2" do
    test "returns [nil] for [DONE] event" do
      event = %{data: "[DONE]", event: nil, id: nil}
      assert OpenAIChat.decode_sse_event(event, nil) == [nil]
    end

    test "extracts content from delta" do
      event = %{
        data: ~s({"choices":[{"delta":{"content":"Hello"}}]}),
        event: nil,
        id: nil
      }

      assert OpenAIChat.decode_sse_event(event, nil) == ["Hello"]
    end

    test "returns empty list for delta without content" do
      event = %{
        data: ~s({"choices":[{"delta":{"role":"assistant"}}]}),
        event: nil,
        id: nil
      }

      assert OpenAIChat.decode_sse_event(event, nil) == []
    end

    test "returns empty list for empty choices" do
      event = %{
        data: ~s({"choices":[]}),
        event: nil,
        id: nil
      }

      assert OpenAIChat.decode_sse_event(event, nil) == []
    end

    test "returns usage tuple for usage-only event" do
      event = %{
        data: ~s({"choices":[],"usage":{"prompt_tokens":10,"completion_tokens":5}}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:usage, usage}] = result
      assert usage.input_tokens == 10
      assert usage.output_tokens == 5
    end

    test "returns empty list for invalid JSON" do
      event = %{data: "not valid json", event: nil, id: nil}
      assert OpenAIChat.decode_sse_event(event, nil) == []
    end

    test "handles multiple choices (uses first)" do
      event = %{
        data: ~s({"choices":[{"delta":{"content":"First"}},{"delta":{"content":"Second"}}]}),
        event: nil,
        id: nil
      }

      assert OpenAIChat.decode_sse_event(event, nil) == ["First"]
    end
  end
end
