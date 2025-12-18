defmodule ReqLlmNext.Wire.OpenAIChatTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Tool
  alias ReqLlmNext.ToolCall
  alias ReqLlmNext.Wire.OpenAIChat

  describe "endpoint/0" do
    test "returns chat completions endpoint" do
      assert OpenAIChat.endpoint() == "/chat/completions"
    end
  end

  describe "encode_body/3" do
    test "encodes basic prompt" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", [])

      assert body.model == "test-model"
      assert body.messages == [%{role: "user", content: "Hello!"}]
      assert body.stream == true
      assert body.stream_options == %{include_usage: true}
    end

    test "includes max_tokens when provided" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", max_tokens: 100)

      assert body.max_tokens == 100
    end

    test "includes temperature when provided" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", temperature: 0.5)

      assert body.temperature == 0.5
    end

    test "includes both max_tokens and temperature" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", max_tokens: 200, temperature: 0.8)

      assert body.max_tokens == 200
      assert body.temperature == 0.8
    end

    test "omits nil values" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello!", [])

      refute Map.has_key?(body, :max_tokens)
      refute Map.has_key?(body, :temperature)
    end

    test "encodes Context with multiple messages" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello"),
          Context.assistant("Hi there!")
        ])

      body = OpenAIChat.encode_body(model, context, [])

      assert length(body.messages) == 3
      assert Enum.at(body.messages, 0).role == "system"
      assert Enum.at(body.messages, 1).role == "user"
      assert Enum.at(body.messages, 2).role == "assistant"
    end

    test "encodes tool message" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.tool_result("call_123", "72°F and sunny")
        ])

      body = OpenAIChat.encode_body(model, context, [])

      tool_msg = Enum.at(body.messages, 1)
      assert tool_msg.role == "tool"
      assert tool_msg.tool_call_id == "call_123"
      assert tool_msg.content == "72°F and sunny"
    end

    test "encodes assistant message with tool calls" do
      model = TestModels.openai()

      tool_call = ToolCall.new("call_abc", "get_weather", ~s({"location":"SF"}))

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.assistant("", tool_calls: [tool_call])
        ])

      body = OpenAIChat.encode_body(model, context, [])

      assistant_msg = Enum.at(body.messages, 1)
      assert assistant_msg.role == "assistant"
      assert length(assistant_msg.tool_calls) == 1
      assert Enum.at(assistant_msg.tool_calls, 0).id == "call_abc"
      assert Enum.at(assistant_msg.tool_calls, 0).type == "function"
      assert Enum.at(assistant_msg.tool_calls, 0).function.name == "get_weather"
      assert Enum.at(assistant_msg.tool_calls, 0).function.arguments == ~s({"location":"SF"})
    end

    test "encodes multi-part content with text only" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.user([ContentPart.text("Hello")])
        ])

      body = OpenAIChat.encode_body(model, context, [])

      assert Enum.at(body.messages, 0).content == "Hello"
    end

    test "encodes multi-part content with image URL" do
      model = TestModels.openai()

      context =
        Context.new([
          Context.user([
            ContentPart.text("What's in this image?"),
            ContentPart.image_url("https://example.com/img.png")
          ])
        ])

      body = OpenAIChat.encode_body(model, context, [])

      content = Enum.at(body.messages, 0).content
      assert is_list(content)
      assert length(content) == 2
      assert Enum.at(content, 0) == %{type: "text", text: "What's in this image?"}

      assert Enum.at(content, 1) == %{
               type: "image_url",
               image_url: %{url: "https://example.com/img.png"}
             }
    end

    test "includes tools when provided" do
      model = TestModels.openai()

      {:ok, tool} =
        Tool.new(
          name: "get_weather",
          description: "Get current weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      body = OpenAIChat.encode_body(model, "Hello", tools: [tool])

      assert Map.has_key?(body, :tools)
      assert length(body.tools) == 1
      assert Enum.at(body.tools, 0)["type"] == "function"
      assert Enum.at(body.tools, 0)["function"]["name"] == "get_weather"
    end

    test "includes raw tool maps when provided" do
      model = TestModels.openai()

      raw_tool = %{
        "type" => "function",
        "function" => %{
          "name" => "search",
          "description" => "Search the web",
          "parameters" => %{"type" => "object", "properties" => %{}}
        }
      }

      body = OpenAIChat.encode_body(model, "Hello", tools: [raw_tool])

      assert Enum.at(body.tools, 0) == raw_tool
    end

    test "omits tools when empty list" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello", tools: [])

      refute Map.has_key?(body, :tools)
    end

    test "includes tool_choice when provided" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello", tool_choice: "auto")

      assert body.tool_choice == "auto"
    end

    test "transforms tool_choice with type and name" do
      model = TestModels.openai()

      body =
        OpenAIChat.encode_body(model, "Hello", tool_choice: %{type: "tool", name: "get_weather"})

      assert body.tool_choice == %{type: "function", function: %{name: "get_weather"}}
    end

    test "includes response_format for object operation with schema" do
      model = TestModels.openai()

      schema = [name: [type: :string, required: true], age: [type: :integer]]
      compiled_schema = %{schema: schema}

      body =
        OpenAIChat.encode_body(model, "Hello",
          operation: :object,
          compiled_schema: compiled_schema
        )

      assert Map.has_key?(body, :response_format)
      assert body.response_format.type == "json_schema"
      assert body.response_format.json_schema.name == "object"
      assert body.response_format.json_schema.strict == true
      assert body.response_format.json_schema.schema["type"] == "object"
    end

    test "omits response_format for non-object operations" do
      model = TestModels.openai()
      body = OpenAIChat.encode_body(model, "Hello", operation: :text)

      refute Map.has_key?(body, :response_format)
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

    test "returns error event for invalid JSON" do
      event = %{data: "not valid json", event: nil, id: nil}
      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:error, %{type: "decode_error", message: message}}] = result
      assert message =~ "Failed to decode SSE event"
    end

    test "handles multiple choices (uses first)" do
      event = %{
        data: ~s({"choices":[{"delta":{"content":"First"}},{"delta":{"content":"Second"}}]}),
        event: nil,
        id: nil
      }

      assert OpenAIChat.decode_sse_event(event, nil) == ["First"]
    end

    test "decodes tool_calls delta" do
      event = %{
        data:
          ~s({"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_123","type":"function","function":{"name":"get_weather","arguments":""}}]}}]}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:tool_call_delta, delta}] = result
      assert delta.index == 0
      assert delta.id == "call_123"
      assert delta.type == "function"
      assert delta.function["name"] == "get_weather"
    end

    test "decodes tool_calls delta with arguments fragment" do
      event = %{
        data:
          ~s({"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"loc"}}]}}]}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:tool_call_delta, delta}] = result
      assert delta.index == 0
      assert delta.function["arguments"] == ~s({"loc)
    end

    test "decodes multiple tool_calls in single delta" do
      event = %{
        data:
          ~s({"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"tool1"}},{"index":1,"id":"call_2","type":"function","function":{"name":"tool2"}}]}}]}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:tool_call_delta, delta1}, {:tool_call_delta, delta2}] = result
      assert delta1.index == 0
      assert delta1.id == "call_1"
      assert delta2.index == 1
      assert delta2.id == "call_2"
    end

    test "decodes API error event" do
      event = %{
        data:
          ~s({"error":{"message":"Rate limit exceeded","type":"rate_limit_error","code":"rate_limit"}}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:error, error}] = result
      assert error.message == "Rate limit exceeded"
      assert error.type == "rate_limit_error"
      assert error.code == "rate_limit"
    end

    test "decodes API error with missing fields" do
      event = %{
        data: ~s({"error":{"message":"Something went wrong"}}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:error, error}] = result
      assert error.message == "Something went wrong"
      assert error.type == "api_error"
      assert error.code == nil
    end

    test "decodes API error with no message" do
      event = %{
        data: ~s({"error":{}}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, nil)
      assert [{:error, error}] = result
      assert error.message == "Unknown API error"
    end

    test "extracts usage from content event" do
      model = TestModels.openai()

      event = %{
        data:
          ~s({"choices":[{"delta":{"content":"Hi"}}],"usage":{"prompt_tokens":10,"completion_tokens":5}}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, model)
      assert ["Hi", {:usage, usage}] = result
      assert usage.input_tokens == 10
      assert usage.output_tokens == 5
    end

    test "extracts standalone usage event" do
      model = TestModels.openai()

      event = %{
        data: ~s({"usage":{"prompt_tokens":100,"completion_tokens":50,"total_tokens":150}}),
        event: nil,
        id: nil
      }

      result = OpenAIChat.decode_sse_event(event, model)
      assert [{:usage, usage}] = result
      assert usage.input_tokens == 100
      assert usage.output_tokens == 50
    end

    test "returns empty list for unknown payload" do
      event = %{
        data: ~s({"id":"chatcmpl-123","object":"chat.completion.chunk"}),
        event: nil,
        id: nil
      }

      assert OpenAIChat.decode_sse_event(event, nil) == []
    end
  end
end
