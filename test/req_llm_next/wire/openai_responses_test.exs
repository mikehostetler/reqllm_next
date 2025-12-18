defmodule ReqLlmNext.Wire.OpenAIResponsesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Wire.OpenAIResponses
  alias ReqLlmNext.Context

  describe "endpoint/0 and path/0" do
    test "returns responses endpoint" do
      assert OpenAIResponses.endpoint() == "/v1/responses"
      assert OpenAIResponses.path() == "/v1/responses"
    end
  end

  describe "encode_body/3" do
    test "encodes string prompt as input array" do
      model = reasoning_model()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      assert body.model == "o1"
      assert body.stream == true
      assert body.input == [%{role: "user", content: [%{type: "input_text", text: "Hello"}]}]
    end

    test "converts system role to developer role" do
      model = reasoning_model()

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
      model = reasoning_model()

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

    test "includes reasoning config when effort specified" do
      model = reasoning_model()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: :high)

      assert body.reasoning == %{effort: "high"}
    end

    test "accepts string reasoning effort" do
      model = reasoning_model()
      body = OpenAIResponses.encode_body(model, "Hello", reasoning_effort: "medium")

      assert body.reasoning == %{effort: "medium"}
    end

    test "uses max_output_tokens instead of max_tokens" do
      model = reasoning_model()
      body = OpenAIResponses.encode_body(model, "Hello", max_tokens: 1000)

      assert body.max_output_tokens == 1000
      refute Map.has_key?(body, :max_tokens)
    end

    test "prioritizes max_output_tokens over alternatives" do
      model = reasoning_model()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          max_output_tokens: 100,
          max_completion_tokens: 200,
          max_tokens: 300
        )

      assert body.max_output_tokens == 100
    end

    test "encodes tools in responses format" do
      model = reasoning_model()

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

    test "encodes tool_choice auto" do
      model = reasoning_model()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: :auto)

      assert body.tool_choice == "auto"
    end

    test "encodes tool_choice none" do
      model = reasoning_model()
      body = OpenAIResponses.encode_body(model, "Hello", tool_choice: :none)

      assert body.tool_choice == "none"
    end

    test "encodes specific tool choice" do
      model = reasoning_model()

      body =
        OpenAIResponses.encode_body(model, "Hello",
          tool_choice: %{type: "function", function: %{name: "get_weather"}}
        )

      assert body.tool_choice == %{type: "function", name: "get_weather"}
    end

    test "omits nil values" do
      model = reasoning_model()
      body = OpenAIResponses.encode_body(model, "Hello", [])

      refute Map.has_key?(body, :max_output_tokens)
      refute Map.has_key?(body, :reasoning)
      refute Map.has_key?(body, :tools)
    end
  end

  describe "decode_sse_event/2 - text content" do
    test "decodes text content from output_text.delta" do
      model = reasoning_model()
      event = %{data: ~s({"type": "response.output_text.delta", "delta": "Hello"})}

      assert ["Hello"] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores empty text delta" do
      model = reasoning_model()
      event = %{data: ~s({"type": "response.output_text.delta", "delta": ""})}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "decodes pre-parsed data map" do
      model = reasoning_model()
      event = %{data: %{"type" => "response.output_text.delta", "delta" => "Text"}}

      assert ["Text"] = OpenAIResponses.decode_sse_event(event, model)
    end
  end

  describe "decode_sse_event/2 - reasoning content" do
    test "decodes reasoning as {:thinking, text}" do
      model = reasoning_model()
      event = %{data: %{"type" => "response.reasoning.delta", "delta" => "Thinking..."}}

      assert [{:thinking, "Thinking..."}] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores empty reasoning delta" do
      model = reasoning_model()
      event = %{data: %{"type" => "response.reasoning.delta", "delta" => ""}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end
  end

  describe "decode_sse_event/2 - usage" do
    test "decodes usage with reasoning_tokens" do
      model = reasoning_model()

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

    test "handles missing reasoning_tokens" do
      model = reasoning_model()

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
    end
  end

  describe "decode_sse_event/2 - function calls" do
    test "decodes function call start from output_item.added" do
      model = reasoning_model()

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

    test "decodes function call arguments delta" do
      model = reasoning_model()

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
  end

  describe "decode_sse_event/2 - terminal events" do
    test "handles [DONE] event" do
      model = reasoning_model()
      event = %{data: "[DONE]"}

      assert [nil] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "decodes completed event" do
      model = reasoning_model()

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

    test "decodes incomplete event with length reason" do
      model = reasoning_model()

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

    test "ignores output_text.done event" do
      model = reasoning_model()
      event = %{data: %{"type" => "response.output_text.done"}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end

    test "ignores unknown event types" do
      model = reasoning_model()
      event = %{data: %{"type" => "response.unknown.type"}}

      assert [] = OpenAIResponses.decode_sse_event(event, model)
    end
  end

  defp reasoning_model do
    %LLMDB.Model{
      id: "o1",
      provider: :openai,
      modalities: %{input: [:text], output: [:text]},
      extra: %{api: "responses"}
    }
  end
end
