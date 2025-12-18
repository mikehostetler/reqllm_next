defmodule ReqLlmNext.Wire.OpenAIResponsesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Wire.OpenAIResponses
  alias ReqLlmNext.Context
  alias ReqLlmNext.TestModels

  describe "endpoint/0 and path/0" do
    test "returns responses endpoint" do
      assert OpenAIResponses.endpoint() == "/v1/responses"
      assert OpenAIResponses.path() == "/v1/responses"
    end
  end

  describe "options_schema/0" do
    test "returns valid schema with max_output_tokens" do
      schema = OpenAIResponses.options_schema()

      assert Keyword.has_key?(schema, :max_output_tokens)
      assert Keyword.has_key?(schema, :max_completion_tokens)
      assert Keyword.has_key?(schema, :max_tokens)
      assert Keyword.has_key?(schema, :reasoning_effort)
    end
  end

  describe "encode_body/3" do
    test "encodes string prompt as input array" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      assert body.model == "o1-test"
      assert body.stream == true
      assert body.input == [%{role: "user", content: [%{type: "input_text", text: "Hello"}]}]
    end

    test "includes stream_options for usage" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      assert body.stream_options == %{include_usage: true}
    end

    test "converts system role to developer role" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.system("You are helpful"),
          Context.user("Hello")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      assert [developer_msg, user_msg] = body.input
      assert developer_msg.role == "developer"
      assert developer_msg.content == [%{type: "input_text", text: "You are helpful"}]
      assert user_msg.role == "user"
    end

    test "uses output_text for assistant messages" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user("Hi"),
          Context.assistant("Hello!")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      assert [user_msg, assistant_msg] = body.input
      assert user_msg.content == [%{type: "input_text", text: "Hi"}]
      assert assistant_msg.role == "assistant"
      assert assistant_msg.content == [%{type: "output_text", text: "Hello!"}]
    end

    test "filters out tool messages from context" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.user("Hello"),
          Context.tool_result("call_123", "Result")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      assert length(body.input) == 1
      assert hd(body.input).role == "user"
    end

    test "encodes image content in user messages" do
      model = TestModels.openai_reasoning()

      context =
        Context.new([
          Context.with_image(:user, "What is this?", "https://example.com/image.png")
        ])

      body = OpenAIResponses.encode_body(model, context, [])

      [msg] = body.input
      assert length(msg.content) == 2
      assert Enum.at(msg.content, 0) == %{type: "input_text", text: "What is this?"}

      assert Enum.at(msg.content, 1) == %{
               type: "image_url",
               image_url: %{url: "https://example.com/image.png"}
             }
    end

    test "includes reasoning config when effort specified" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: :high)

      assert body.reasoning == %{effort: "high"}
    end

    test "accepts string reasoning effort" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: "medium")

      assert body.reasoning == %{effort: "medium"}
    end

    test "ignores invalid reasoning effort" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: 123)

      refute Map.has_key?(body, :reasoning)
    end

    test "uses max_output_tokens instead of max_tokens" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", max_tokens: 1000)

      assert body.max_output_tokens == 1000
      refute Map.has_key?(body, :max_tokens)
    end

    test "prioritizes max_output_tokens over alternatives" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          max_output_tokens: 100,
          max_completion_tokens: 200,
          max_tokens: 300
        )

      assert body.max_output_tokens == 100
    end

    test "uses max_completion_tokens when max_output_tokens not provided" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          max_completion_tokens: 200,
          max_tokens: 300
        )

      assert body.max_output_tokens == 200
    end

    test "encodes tools in responses format" do
      model = TestModels.openai_reasoning()

      tool =
        ReqLlmNext.Tool.new!(
          name: "get_weather",
          description: "Get weather",
          parameter_schema: [location: [type: :string, required: true]],
          callback: fn _ -> {:ok, "sunny"} end
        )

      body = OpenAIResponses.encode_body(model, "Hello", tools: [tool])

      assert [encoded_tool] = body.tools
      assert encoded_tool.type == "function"
      assert encoded_tool.name == "get_weather"
      assert encoded_tool.description == "Get weather"
      assert encoded_tool.strict == true
    end

    test "passes through raw tool maps" do
      model = TestModels.openai_reasoning()
      raw_tool = %{type: "function", name: "raw", description: "Raw tool"}

      body = OpenAIResponses.encode_body(model, "Hello", tools: [raw_tool])

      assert body.tools == [raw_tool]
    end

    test "does not add tools key when tools is empty list" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tools: [])

      refute Map.has_key?(body, :tools)
    end

    test "encodes tool_choice auto as atom" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: :auto)

      assert body.tool_choice == "auto"
    end

    test "encodes tool_choice auto as string" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: "auto")

      assert body.tool_choice == "auto"
    end

    test "encodes tool_choice none as atom" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: :none)

      assert body.tool_choice == "none"
    end

    test "encodes tool_choice none as string" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: "none")

      assert body.tool_choice == "none"
    end

    test "encodes tool_choice required as atom" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: :required)

      assert body.tool_choice == "required"
    end

    test "encodes tool_choice required as string" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: "required")

      assert body.tool_choice == "required"
    end

    test "encodes specific tool choice with function format" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          tool_choice: %{type: "function", function: %{name: "get_weather"}}
        )

      assert body.tool_choice == %{type: "function", name: "get_weather"}
    end

    test "encodes specific tool choice with tool format" do
      model = TestModels.openai_reasoning()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          tool_choice: %{type: "tool", name: "get_weather"}
        )

      assert body.tool_choice == %{type: "function", name: "get_weather"}
    end

    test "ignores unknown tool_choice values" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: :unknown)

      refute Map.has_key?(body, :tool_choice)
    end

    test "omits nil values" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      refute Map.has_key?(body, :max_output_tokens)
      refute Map.has_key?(body, :reasoning)
      refute Map.has_key?(body, :tools)
    end

    test "encodes response format for object operation with schema" do
      model = TestModels.openai_reasoning()

      schema = [
        name: [type: :string, required: true],
        age: [type: :integer]
      ]

      compiled = %{schema: schema}

      body =
        OpenAIResponses.encode_body(model, "Hello",
          operation: :object,
          compiled_schema: compiled
        )

      assert body.text.format.type == "json_schema"
      assert body.text.format.name == "object"
      assert body.text.format.strict == true
      assert is_map(body.text.format.schema)
    end

    test "does not add response format when operation is not object" do
      model = TestModels.openai_reasoning()
      body = OpenAIResponses.encode_body(model, "Hello", operation: :text)

      refute Map.has_key?(body, :text)
    end
  end

  describe "decode_sse_event/2 - text content" do
    test "decodes text content from output_text.delta" do
      model = TestModels.openai_reasoning()
      event = %{data: ~s({"type": "response.output_text.delta", "delta": "Hello"})}

      assert ["Hello"] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores empty text delta" do
      model = TestModels.openai_reasoning()
      event = %{data: ~s({"type": "response.output_text.delta", "delta": ""})}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores missing delta" do
      model = TestModels.openai_reasoning()
      event = %{data: ~s({"type": "response.output_text.delta"})}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "decodes pre-parsed data map" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.output_text.delta", "delta" => "Text"}}

      assert ["Text"] = OpenAIResponses.decode_sse_event(event, model)
    end
  end

  describe "decode_sse_event/2 - reasoning content" do
    test "decodes reasoning as {:thinking, text}" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.reasoning.delta", "delta" => "Thinking..."}}

      assert [{:thinking, "Thinking..."}] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores empty reasoning delta" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.reasoning.delta", "delta" => ""}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores missing reasoning delta" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.reasoning.delta"}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end
  end

  describe "decode_sse_event/2 - usage" do
    test "decodes usage with reasoning_tokens" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.usage",
          "usage" => %{
            "input_tokens" => 10,
            "output_tokens" => 20,
            "output_tokens_details" => %{"reasoning_tokens" => 5}
          }
        }
      }

      assert [{:usage, usage}] = OpenAIResponses.decode_sse_event(event, model)
      assert usage.input_tokens == 10
      assert usage.output_tokens == 20
      assert usage.total_tokens == 30
      assert usage.reasoning_tokens == 5
    end

    test "decodes usage with reasoning_tokens at top level" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.usage",
          "usage" => %{
            "input_tokens" => 10,
            "output_tokens" => 20,
            "reasoning_tokens" => 8
          }
        }
      }

      assert [{:usage, usage}] = OpenAIResponses.decode_sse_event(event, model)
      assert usage.reasoning_tokens == 8
    end

    test "handles missing reasoning_tokens" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.usage",
          "usage" => %{
            "input_tokens" => 10,
            "output_tokens" => 20
          }
        }
      }

      assert [{:usage, usage}] = OpenAIResponses.decode_sse_event(event, model)
      assert usage.input_tokens == 10
      assert usage.output_tokens == 20
      refute Map.has_key?(usage, :reasoning_tokens)
    end

    test "decodes usage with cached_tokens" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.usage",
          "usage" => %{
            "input_tokens" => 10,
            "output_tokens" => 20,
            "input_tokens_details" => %{"cached_tokens" => 5}
          }
        }
      }

      assert [{:usage, usage}] = OpenAIResponses.decode_sse_event(event, model)
      assert usage.cache_read_tokens == 5
    end
  end

  describe "decode_sse_event/2 - function calls" do
    test "decodes function call start from output_item.added" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.output_item.added",
          "output_index" => 0,
          "item" => %{
            "type" => "function_call",
            "call_id" => "call_123",
            "name" => "get_weather"
          }
        }
      }

      assert [{:tool_call_start, start}] = OpenAIResponses.decode_sse_event(event, model)
      assert start.index == 0
      assert start.id == "call_123"
      assert start.name == "get_weather"
    end

    test "uses id field when call_id is missing" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.output_item.added",
          "output_index" => 0,
          "item" => %{
            "type" => "function_call",
            "id" => "call_456",
            "name" => "get_weather"
          }
        }
      }

      assert [{:tool_call_start, start}] = OpenAIResponses.decode_sse_event(event, model)
      assert start.id == "call_456"
    end

    test "ignores output_item.added without function name" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.output_item.added",
          "item" => %{
            "type" => "function_call",
            "call_id" => "call_123",
            "name" => ""
          }
        }
      }

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores output_item.added for non-function types" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.output_item.added",
          "item" => %{
            "type" => "text"
          }
        }
      }

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "decodes function call arguments delta" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.function_call_arguments.delta",
          "output_index" => 0,
          "delta" => ~s({"location":)
        }
      }

      assert [{:tool_call_delta, delta}] = OpenAIResponses.decode_sse_event(event, model)
      assert delta.index == 0
      assert delta.function["arguments"] == ~s({"location":)
    end

    test "uses index field for function_call_arguments.delta" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.function_call_arguments.delta",
          "index" => 1,
          "delta" => ~s({"a":1})
        }
      }

      assert [{:tool_call_delta, delta}] = OpenAIResponses.decode_sse_event(event, model)
      assert delta.index == 1
    end

    test "ignores empty function_call_arguments.delta" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.function_call_arguments.delta",
          "output_index" => 0,
          "delta" => ""
        }
      }

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "decodes function_call.delta with name" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.function_call.delta",
          "output_index" => 0,
          "call_id" => "call_789",
          "delta" => %{
            "name" => "get_weather"
          }
        }
      }

      assert [{:tool_call_start, start}] = OpenAIResponses.decode_sse_event(event, model)
      assert start.index == 0
      assert start.id == "call_789"
      assert start.name == "get_weather"
    end

    test "decodes function_call.delta with arguments" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.function_call.delta",
          "output_index" => 1,
          "delta" => %{
            "arguments" => ~s({"city":"NYC"})
          }
        }
      }

      assert [{:tool_call_delta, delta}] = OpenAIResponses.decode_sse_event(event, model)
      assert delta.index == 1
      assert delta.function["arguments"] == ~s({"city":"NYC"})
    end

    test "decodes function_call.delta with both name and arguments" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.function_call.delta",
          "output_index" => 0,
          "call_id" => "call_abc",
          "delta" => %{
            "name" => "get_info",
            "arguments" => ~s({"id":1})
          }
        }
      }

      result = OpenAIResponses.decode_sse_event(event, model)
      assert length(result) == 2
      assert {:tool_call_start, start} = Enum.at(result, 0)
      assert {:tool_call_delta, delta} = Enum.at(result, 1)
      assert start.name == "get_info"
      assert delta.function["arguments"] == ~s({"id":1})
    end
  end

  describe "decode_sse_event/2 - terminal events" do
    test "handles [DONE] event" do
      model = TestModels.openai_reasoning()
      event = %{data: "[DONE]"}

      assert [nil] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "decodes completed event" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.completed",
          "response" => %{
            "id" => "resp_123",
            "usage" => %{
              "input_tokens" => 10,
              "output_tokens" => 20
            }
          }
        }
      }

      result = OpenAIResponses.decode_sse_event(event, model)
      assert length(result) >= 1

      meta =
        Enum.find_value(result, fn
          {:meta, m} -> m
          _ -> nil
        end)

      assert meta.terminal? == true
      assert meta.finish_reason == :stop
      assert meta.response_id == "resp_123"
    end

    test "decodes completed event without usage" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.completed",
          "response" => %{
            "id" => "resp_456"
          }
        }
      }

      result = OpenAIResponses.decode_sse_event(event, model)
      assert [{:meta, meta}] = result
      assert meta.terminal? == true
      assert meta.response_id == "resp_456"
    end

    test "decodes completed event with reasoning_tokens in usage" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.completed",
          "response" => %{
            "id" => "resp_789",
            "usage" => %{
              "input_tokens" => 10,
              "output_tokens" => 30,
              "total_tokens" => 40,
              "output_tokens_details" => %{"reasoning_tokens" => 15}
            }
          }
        }
      }

      result = OpenAIResponses.decode_sse_event(event, model)

      usage =
        Enum.find_value(result, fn
          {:usage, u} -> u
          _ -> nil
        end)

      assert usage.reasoning_tokens == 15
    end

    test "decodes incomplete event with length reason" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.incomplete",
          "reason" => "max_output_tokens"
        }
      }

      assert [{:meta, meta}] = OpenAIResponses.decode_sse_event(event, model)
      assert meta.terminal? == true
      assert meta.finish_reason == :length
    end

    test "decodes incomplete event with max_tokens reason" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.incomplete",
          "reason" => "max_tokens"
        }
      }

      assert [{:meta, meta}] = OpenAIResponses.decode_sse_event(event, model)
      assert meta.finish_reason == :length
    end

    test "decodes incomplete event with stop reason" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.incomplete",
          "reason" => "stop"
        }
      }

      assert [{:meta, meta}] = OpenAIResponses.decode_sse_event(event, model)
      assert meta.finish_reason == :stop
    end

    test "decodes incomplete event with tool_calls reason" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.incomplete",
          "reason" => "tool_calls"
        }
      }

      assert [{:meta, meta}] = OpenAIResponses.decode_sse_event(event, model)
      assert meta.finish_reason == :tool_calls
    end

    test "decodes incomplete event with content_filter reason" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.incomplete",
          "reason" => "content_filter"
        }
      }

      assert [{:meta, meta}] = OpenAIResponses.decode_sse_event(event, model)
      assert meta.finish_reason == :content_filter
    end

    test "decodes incomplete event with unknown reason defaults to error" do
      model = TestModels.openai_reasoning()

      event = %{
        data: %{
          "type" => "response.incomplete",
          "reason" => "something_unknown"
        }
      }

      assert [{:meta, meta}] = OpenAIResponses.decode_sse_event(event, model)
      assert meta.finish_reason == :error
    end

    test "ignores output_text.done event" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.output_text.done"}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores output_item.done event" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.output_item.done"}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores function_call_arguments.done event" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.function_call_arguments.done"}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores unknown event types" do
      model = TestModels.openai_reasoning()
      event = %{data: %{"type" => "response.unknown.type"}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end
  end

  describe "decode_sse_event/2 - error handling" do
    test "decodes API error event" do
      model = TestModels.openai_reasoning()

      event = %{
        data:
          ~s({"error":{"type":"rate_limit_error","message":"Too many requests","code":"rate_limited"}})
      }

      result = OpenAIResponses.decode_sse_event(event, model)
      assert [{:error, error}] = result
      assert error.type == "rate_limit_error"
      assert error.message == "Too many requests"
      assert error.code == "rate_limited"
    end

    test "handles error with missing fields" do
      model = TestModels.openai_reasoning()

      event = %{
        data: ~s({"error":{}})
      }

      result = OpenAIResponses.decode_sse_event(event, model)
      assert [{:error, error}] = result
      assert error.message == "Unknown API error"
      assert error.type == "api_error"
    end

    test "returns error for invalid JSON" do
      model = TestModels.openai_reasoning()
      event = %{data: "not valid json"}

      result = OpenAIResponses.decode_sse_event(event, model)
      assert [{:error, %{type: "decode_error", message: message}}] = result
      assert message =~ "Failed to decode SSE event"
    end

    test "returns empty list for unhandled event structure" do
      model = TestModels.openai_reasoning()
      event = %{something: "else"}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end
  end
end
