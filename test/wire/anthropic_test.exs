defmodule ReqLlmNext.Wire.AnthropicTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Tool
  alias ReqLlmNext.ToolCall
  alias ReqLlmNext.Wire.Anthropic

  describe "endpoint/0" do
    test "returns messages endpoint" do
      assert Anthropic.endpoint() == "/v1/messages"
    end
  end

  describe "headers/1" do
    test "returns base headers with version and content-type" do
      headers = Anthropic.headers([])

      assert {"anthropic-version", "2023-06-01"} in headers
      assert {"content-type", "application/json"} in headers
    end

    test "includes thinking beta flag when thinking option is present" do
      headers = Anthropic.headers(thinking: %{type: "enabled", budget_tokens: 4096})

      assert {"anthropic-beta", "interleaved-thinking-2025-05-14"} in headers
    end

    test "includes thinking beta flag when reasoning_effort is present" do
      headers = Anthropic.headers(reasoning_effort: :high)

      assert {"anthropic-beta", "interleaved-thinking-2025-05-14"} in headers
    end

    test "includes prompt caching beta flag" do
      headers = Anthropic.headers(anthropic_prompt_cache: true)

      assert {"anthropic-beta", "prompt-caching-2024-07-31"} in headers
    end

    test "combines multiple beta flags" do
      headers =
        Anthropic.headers(
          thinking: %{type: "enabled", budget_tokens: 4096},
          anthropic_prompt_cache: true
        )

      beta_header = Enum.find(headers, fn {k, _} -> k == "anthropic-beta" end)
      assert beta_header != nil
      {_, beta_value} = beta_header
      assert "interleaved-thinking-2025-05-14" in String.split(beta_value, ",")
      assert "prompt-caching-2024-07-31" in String.split(beta_value, ",")
    end

    test "does not include beta header when no beta features enabled" do
      headers = Anthropic.headers([])

      refute Enum.any?(headers, fn {k, _} -> k == "anthropic-beta" end)
    end
  end

  describe "map_reasoning_effort_to_budget/1" do
    test "maps atom :low to 1024" do
      assert Anthropic.map_reasoning_effort_to_budget(:low) == 1024
    end

    test "maps atom :medium to 2048" do
      assert Anthropic.map_reasoning_effort_to_budget(:medium) == 2048
    end

    test "maps atom :high to 4096" do
      assert Anthropic.map_reasoning_effort_to_budget(:high) == 4096
    end

    test "maps string 'low' to 1024" do
      assert Anthropic.map_reasoning_effort_to_budget("low") == 1024
    end

    test "maps string 'medium' to 2048" do
      assert Anthropic.map_reasoning_effort_to_budget("medium") == 2048
    end

    test "maps string 'high' to 4096" do
      assert Anthropic.map_reasoning_effort_to_budget("high") == 4096
    end

    test "defaults unknown values to medium (2048)" do
      assert Anthropic.map_reasoning_effort_to_budget(:unknown) == 2048
      assert Anthropic.map_reasoning_effort_to_budget("invalid") == 2048
    end
  end

  describe "encode_body/3" do
    test "encodes basic prompt with default max_tokens" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", [])

      assert body.model == "test-model"
      assert body.messages == [%{role: "user", content: "Hello!"}]
      assert body.stream == true
      assert body.max_tokens == 1024
    end

    test "uses provided max_tokens" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", max_tokens: 2048)

      assert body.max_tokens == 2048
    end

    test "includes temperature when provided" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", temperature: 0.7)

      assert body.temperature == 0.7
    end

    test "omits temperature when not provided" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", [])

      refute Map.has_key?(body, :temperature)
    end

    test "omits temperature when thinking mode is enabled" do
      model = TestModels.anthropic()

      body =
        Anthropic.encode_body(model, "Hello!",
          thinking: %{type: "enabled", budget_tokens: 4096},
          temperature: 0.7
        )

      refute Map.has_key?(body, :temperature)
      assert body.thinking == %{type: "enabled", budget_tokens: 4096}
    end

    test "omits temperature when reasoning_effort is set" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", reasoning_effort: :high, temperature: 0.5)

      refute Map.has_key?(body, :temperature)
    end

    test "encodes thinking config from reasoning_effort" do
      model = TestModels.anthropic()
      body = Anthropic.encode_body(model, "Hello!", reasoning_effort: :high)

      assert body.thinking == %{type: "enabled", budget_tokens: 4096}
    end

    test "encodes thinking config from explicit thinking option" do
      model = TestModels.anthropic()

      body =
        Anthropic.encode_body(model, "Hello!", thinking: %{type: "enabled", budget_tokens: 8192})

      assert body.thinking == %{type: "enabled", budget_tokens: 8192}
    end

    test "encodes context with system message" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body = Anthropic.encode_body(model, context, [])

      assert body.system == "You are helpful"
      assert length(body.messages) == 1
      assert hd(body.messages).role == "user"
    end

    test "encodes multi-turn context" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user("Hello"),
          Context.assistant("Hi there!"),
          Context.user("How are you?")
        ])

      body = Anthropic.encode_body(model, context, [])

      assert length(body.messages) == 3
      assert Enum.at(body.messages, 0).role == "user"
      assert Enum.at(body.messages, 1).role == "assistant"
      assert Enum.at(body.messages, 2).role == "user"
    end

    test "encodes tool result messages" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.assistant("",
            tool_calls: [ToolCall.new("call_123", "get_weather", ~s({"location":"SF"}))]
          ),
          Context.tool_result("call_123", "Sunny, 72F")
        ])

      body = Anthropic.encode_body(model, context, [])

      tool_msg = Enum.at(body.messages, 2)
      assert tool_msg.role == "user"
      assert [%{type: "tool_result", tool_use_id: "call_123"}] = tool_msg.content
    end

    test "encodes assistant message with tool calls" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.user("What's the weather?"),
          Context.assistant("Let me check",
            tool_calls: [ToolCall.new("call_456", "get_weather", ~s({"location":"NYC"}))]
          )
        ])

      body = Anthropic.encode_body(model, context, [])

      assistant_msg = Enum.at(body.messages, 1)
      assert assistant_msg.role == "assistant"

      assert [
               %{type: "text", text: "Let me check"},
               %{
                 type: "tool_use",
                 id: "call_456",
                 name: "get_weather",
                 input: %{"location" => "NYC"}
               }
             ] = assistant_msg.content
    end

    test "encodes tools when provided" do
      model = TestModels.anthropic()

      tool =
        Tool.new!(
          name: "get_weather",
          description: "Get weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      body = Anthropic.encode_body(model, "Hello", tools: [tool])

      assert is_list(body.tools)
      assert length(body.tools) == 1
    end

    test "passes through raw tool maps" do
      model = TestModels.anthropic()
      raw_tool = %{name: "raw_tool", description: "A raw tool", input_schema: %{}}

      body = Anthropic.encode_body(model, "Hello", tools: [raw_tool])

      assert body.tools == [raw_tool]
    end

    test "encodes tool_choice" do
      model = TestModels.anthropic()

      body =
        Anthropic.encode_body(model, "Hello", tool_choice: %{type: "tool", name: "get_weather"})

      assert body.tool_choice == %{type: "tool", name: "get_weather"}
    end

    test "passes through generic tool_choice" do
      model = TestModels.anthropic()

      body = Anthropic.encode_body(model, "Hello", tool_choice: %{type: "auto"})

      assert body.tool_choice == %{type: "auto"}
    end

    test "encodes system prompt with cache control when caching enabled" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body = Anthropic.encode_body(model, context, anthropic_prompt_cache: true)

      assert is_list(body.system)
      [cached_block] = body.system
      assert cached_block.type == "text"
      assert cached_block.text == "You are helpful"
      assert cached_block.cache_control == %{type: "ephemeral"}
    end

    test "encodes system prompt with custom cache TTL" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body =
        Anthropic.encode_body(model, context,
          anthropic_prompt_cache: true,
          anthropic_prompt_cache_ttl: 300
        )

      [cached_block] = body.system
      assert cached_block.cache_control == %{type: "ephemeral", ttl: 300}
    end

    test "encodes image content part" do
      model = TestModels.anthropic()

      context =
        Context.new([
          Context.with_image(:user, "What is this?", "https://example.com/image.png")
        ])

      body = Anthropic.encode_body(model, context, [])

      [msg] = body.messages
      assert length(msg.content) == 2
      [text_part, image_part] = msg.content
      assert text_part == %{type: "text", text: "What is this?"}

      assert image_part == %{
               type: "image",
               source: %{type: "url", url: "https://example.com/image.png"}
             }
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

    test "extracts text from content_block_delta with type text_delta" do
      event = %{
        data: ~s({"type":"content_block_delta","delta":{"type":"text_delta","text":"World"}}),
        event: nil,
        id: nil
      }

      assert Anthropic.decode_sse_event(event, nil) == ["World"]
    end

    test "returns empty list for message_start event" do
      event = %{
        data: ~s({"type":"message_start","message":{"id":"msg_123"}}),
        event: nil,
        id: nil
      }

      assert Anthropic.decode_sse_event(event, nil) == []
    end

    test "returns empty list for content_block_start event (text type)" do
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

    test "returns error event for invalid JSON" do
      event = %{data: "not valid json", event: nil, id: nil}
      result = Anthropic.decode_sse_event(event, nil)
      assert [{:error, %{type: "decode_error", message: message}}] = result
      assert message =~ "Failed to decode SSE event"
    end

    test "decodes API error event" do
      event = %{
        data:
          ~s({"type":"error","error":{"type":"rate_limit_error","message":"Too many requests"}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:error, %{type: "rate_limit_error", message: "Too many requests"}}] = result
    end

    test "decodes thinking_start event" do
      event = %{
        data: ~s({"type":"content_block_start","content_block":{"type":"thinking"}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:thinking_start, nil}] = result
    end

    test "decodes thinking_start event with initial text" do
      event = %{
        data:
          ~s({"type":"content_block_start","content_block":{"type":"thinking","thinking":"Let me think..."}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:thinking_start, nil}, {:thinking, "Let me think..."}] = result
    end

    test "decodes thinking_start event with text field" do
      event = %{
        data:
          ~s({"type":"content_block_start","content_block":{"type":"thinking","text":"Initial thought"}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:thinking_start, nil}, {:thinking, "Initial thought"}] = result
    end

    test "decodes thinking_delta event with thinking field" do
      event = %{
        data:
          ~s({"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"more thoughts"}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:thinking, "more thoughts"}] = result
    end

    test "decodes thinking_delta event with text field" do
      event = %{
        data:
          ~s({"type":"content_block_delta","delta":{"type":"thinking_delta","text":"alternative format"}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:thinking, "alternative format"}] = result
    end

    test "decodes tool_use content_block_start" do
      event = %{
        data:
          ~s({"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_123","name":"get_weather"}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:tool_call_start, %{index: 0, id: "toolu_123", name: "get_weather"}}] = result
    end

    test "decodes input_json_delta for tool arguments" do
      event = %{
        data:
          ~s({"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"location\\""}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert [{:tool_call_delta, %{index: 0, partial_json: "{\"location\""}}] = result
    end
  end
end
