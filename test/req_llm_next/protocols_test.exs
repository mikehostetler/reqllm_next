defmodule ReqLlmNext.ProtocolsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.ToolCall

  describe "Inspect.ContentPart" do
    test "inspects text content part" do
      part = ContentPart.text("Hello world")
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":text"
      assert result =~ "Hello world"
    end

    test "inspects text content part with long text truncates" do
      long_text = String.duplicate("a", 50)
      part = ContentPart.text(long_text)
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ "..."
      refute result =~ String.duplicate("a", 50)
    end

    test "inspects text content part with nil text" do
      part = %ContentPart{type: :text, text: nil}
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":text"
      assert result =~ "nil"
    end

    test "inspects thinking content part" do
      part = ContentPart.thinking("Let me think about this")
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":thinking"
      assert result =~ "Let me think"
    end

    test "inspects image_url content part" do
      part = ContentPart.image_url("https://example.com/img.png")
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":image_url"
      assert result =~ "url: https://example.com/img.png"
    end

    test "inspects image content part with binary data" do
      part = ContentPart.image(<<1, 2, 3, 4, 5>>, "image/jpeg")
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":image"
      assert result =~ "image/jpeg"
      assert result =~ "5 bytes"
    end

    test "inspects file content part with binary data" do
      part = ContentPart.file(<<1, 2, 3>>, "doc.pdf", "application/pdf")
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":file"
      assert result =~ "application/pdf"
      assert result =~ "3 bytes"
    end

    test "inspects file content part with nil data" do
      part = %ContentPart{type: :file, data: nil, media_type: "application/pdf"}
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":file"
      assert result =~ "0 bytes"
    end
  end

  describe "Jason.Encoder.ContentPart" do
    test "encodes text content part" do
      part = ContentPart.text("Hello")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "text"
      assert decoded["text"] == "Hello"
    end

    test "encodes thinking content part" do
      part = ContentPart.thinking("Thinking...")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "thinking"
      assert decoded["text"] == "Thinking..."
    end

    test "encodes image_url content part" do
      part = ContentPart.image_url("https://example.com/img.png")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "image_url"
      assert decoded["url"] == "https://example.com/img.png"
    end

    test "encodes image content part with base64 data" do
      binary_data = <<1, 2, 3, 4, 5>>
      part = ContentPart.image(binary_data, "image/png")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "image"
      assert decoded["media_type"] == "image/png"
      assert decoded["data"] == Base.encode64(binary_data)
    end

    test "encodes file content part with base64 data" do
      binary_data = "file contents"
      part = ContentPart.file(binary_data, "test.txt", "text/plain")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "file"
      assert decoded["filename"] == "test.txt"
      assert decoded["media_type"] == "text/plain"
      assert decoded["data"] == Base.encode64(binary_data)
    end

    test "encodes content part with metadata" do
      part = ContentPart.text("Hello", %{source: "api"})
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["metadata"] == %{"source" => "api"}
    end

    test "encodes content part without binary data" do
      part = %ContentPart{type: :text, text: "Hello", data: nil}
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "text"
      assert decoded["data"] == nil
    end
  end

  describe "Jason.Encoder.ToolCall" do
    test "encodes tool call with all fields" do
      tc = ToolCall.new("call_123", "get_weather", ~s({"location":"SF"}))
      json = Jason.encode!(tc)
      decoded = Jason.decode!(json)

      assert decoded["id"] == "call_123"
      assert decoded["type"] == "function"
      assert decoded["function"]["name"] == "get_weather"
      assert decoded["function"]["arguments"] == ~s({"location":"SF"})
    end

    test "encodes tool call with empty arguments" do
      tc = ToolCall.new("call_456", "get_time", "{}")
      json = Jason.encode!(tc)
      decoded = Jason.decode!(json)

      assert decoded["id"] == "call_456"
      assert decoded["function"]["name"] == "get_time"
      assert decoded["function"]["arguments"] == "{}"
    end

    test "encodes tool call and preserves JSON structure" do
      tc = ToolCall.new("call_789", "complex_func", ~s({"a":1,"b":"test","c":true}))
      json = Jason.encode!(tc)

      assert is_binary(json)
      assert String.contains?(json, "call_789")
      assert String.contains?(json, "complex_func")
    end

    test "encoded tool call is valid JSON" do
      tc = ToolCall.new("call_abc", "my_func", ~s({"key":"value"}))
      json = Jason.encode!(tc)

      assert {:ok, _} = Jason.decode(json)
    end
  end
end
