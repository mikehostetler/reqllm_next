defmodule ReqLlmNext.Wire.AnthropicTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Wire.Anthropic

  describe "endpoint/0" do
    test "returns messages endpoint" do
      assert Anthropic.endpoint() == "/v1/messages"
    end
  end

  describe "encode_body/3" do
    test "encodes basic prompt with default max_tokens" do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      body = Anthropic.encode_body(model, "Hello!", [])

      assert body.model == "claude-sonnet-4-20250514"
      assert body.messages == [%{role: "user", content: "Hello!"}]
      assert body.stream == true
      assert body.max_tokens == 1024
    end

    test "uses provided max_tokens" do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      body = Anthropic.encode_body(model, "Hello!", max_tokens: 2048)

      assert body.max_tokens == 2048
    end

    test "includes temperature when provided" do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      body = Anthropic.encode_body(model, "Hello!", temperature: 0.7)

      assert body.temperature == 0.7
    end

    test "omits temperature when not provided" do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      body = Anthropic.encode_body(model, "Hello!", [])

      refute Map.has_key?(body, :temperature)
    end
  end

  describe "options_schema/0" do
    test "returns valid NimbleOptions-style schema" do
      schema = Anthropic.options_schema()

      assert Keyword.has_key?(schema, :max_tokens)
      assert Keyword.has_key?(schema, :temperature)
      assert Keyword.has_key?(schema, :top_p)
      assert Keyword.has_key?(schema, :top_k)
    end

    test "max_tokens has default value" do
      schema = Anthropic.options_schema()
      assert schema[:max_tokens][:default] == 1024
    end
  end

  describe "decode_sse_event/2" do
    test "returns [nil] for message_stop event" do
      event = %{data: ~s({"type":"message_stop"}), event: nil, id: nil}
      assert Anthropic.decode_sse_event(event, nil) == [nil]
    end

    test "extracts text from content_block_delta" do
      event = %{
        data: ~s({"type":"content_block_delta","delta":{"text":"Hello"}}),
        event: nil,
        id: nil
      }

      assert Anthropic.decode_sse_event(event, nil) == ["Hello"]
    end

    test "returns empty list for message_start event" do
      event = %{
        data: ~s({"type":"message_start","message":{"id":"msg_123"}}),
        event: nil,
        id: nil
      }

      assert Anthropic.decode_sse_event(event, nil) == []
    end

    test "returns empty list for content_block_start event" do
      event = %{
        data: ~s({"type":"content_block_start","content_block":{"type":"text"}}),
        event: nil,
        id: nil
      }

      assert Anthropic.decode_sse_event(event, nil) == []
    end

    test "returns empty list for content_block_stop event" do
      event = %{
        data: ~s({"type":"content_block_stop"}),
        event: nil,
        id: nil
      }

      assert Anthropic.decode_sse_event(event, nil) == []
    end

    test "returns usage tuple for message_delta event with usage" do
      event = %{
        data: ~s({"type":"message_delta","usage":{"output_tokens":10}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:usage, usage}] = result
      assert usage.output_tokens == 10
    end

    test "returns empty list for ping event" do
      event = %{data: ~s({"type":"ping"}), event: nil, id: nil}
      assert Anthropic.decode_sse_event(event, nil) == []
    end

    test "returns empty list for invalid JSON" do
      event = %{data: "not valid json", event: nil, id: nil}
      assert Anthropic.decode_sse_event(event, nil) == []
    end
  end
end
