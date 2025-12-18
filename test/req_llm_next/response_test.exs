defmodule ReqLlmNext.ResponseTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Response
  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{Message, ContentPart}
  alias ReqLlmNext.ToolCall

  describe "struct definition (Zoi)" do
    test "schema/0 returns Zoi schema" do
      schema = Response.schema()
      assert is_struct(schema)
    end

    test "struct has all expected fields" do
      fields =
        Map.keys(%Response{
          id: "test",
          model: %LLMDB.Model{id: "test", provider: :openai},
          context: Context.new(),
          message: nil,
          usage: nil,
          finish_reason: nil
        })

      expected = [
        :id,
        :model,
        :context,
        :message,
        :object,
        :stream?,
        :stream,
        :usage,
        :finish_reason,
        :provider_meta,
        :error,
        :__struct__
      ]

      assert Enum.sort(fields) == Enum.sort(expected)
    end

    test "enforces required fields" do
      assert_raise ArgumentError, fn ->
        struct!(Response, %{})
      end
    end

    test "provides default values" do
      response = %Response{
        id: "test",
        model: %LLMDB.Model{id: "test", provider: :openai},
        context: Context.new(),
        message: nil,
        usage: nil,
        finish_reason: nil
      }

      assert response.object == nil
      assert response.stream? == false
      assert response.stream == nil
      assert response.provider_meta == %{}
      assert response.error == nil
    end

    test "accepts valid finish_reason atoms" do
      for reason <- [:stop, :length, :tool_calls, :content_filter, :error, nil] do
        response = %Response{
          id: "test",
          model: %LLMDB.Model{id: "test", provider: :openai},
          context: Context.new(),
          message: nil,
          usage: nil,
          finish_reason: reason
        }

        assert response.finish_reason == reason
      end
    end
  end

  defp build_response(attrs) do
    defaults = %{
      id: "resp_123",
      model: %LLMDB.Model{id: "gpt-4o", provider: :openai},
      context: Context.new(),
      message: nil,
      usage: nil,
      finish_reason: nil
    }

    struct!(Response, Map.merge(defaults, attrs))
  end

  describe "text/1" do
    test "extracts text from message content" do
      message = %Message{
        role: :assistant,
        content: [ContentPart.text("Hello, world!")]
      }

      response = build_response(%{message: message})
      assert Response.text(response) == "Hello, world!"
    end

    test "concatenates multiple text parts" do
      message = %Message{
        role: :assistant,
        content: [
          ContentPart.text("Hello, "),
          ContentPart.text("world!")
        ]
      }

      response = build_response(%{message: message})
      assert Response.text(response) == "Hello, world!"
    end

    test "returns nil when no message" do
      response = build_response(%{message: nil})
      assert Response.text(response) == nil
    end

    test "returns empty string when message has no text parts" do
      message = %Message{
        role: :assistant,
        content: []
      }

      response = build_response(%{message: message})
      assert Response.text(response) == ""
    end
  end

  describe "thinking/1" do
    test "extracts thinking content from message" do
      message = %Message{
        role: :assistant,
        content: [
          %ContentPart{type: :thinking, text: "Let me think..."},
          ContentPart.text("The answer is 42.")
        ]
      }

      response = build_response(%{message: message})
      assert Response.thinking(response) == "Let me think..."
    end

    test "returns nil when no message" do
      response = build_response(%{message: nil})
      assert Response.thinking(response) == nil
    end

    test "returns empty string when no thinking parts" do
      message = %Message{
        role: :assistant,
        content: [ContentPart.text("Hello")]
      }

      response = build_response(%{message: message})
      assert Response.thinking(response) == ""
    end
  end

  describe "tool_calls/1" do
    test "extracts tool calls from message" do
      tool_call = ToolCall.new("call_1", "get_weather", ~s({"location":"SF"}))

      message = %Message{
        role: :assistant,
        content: [],
        tool_calls: [tool_call]
      }

      response = build_response(%{message: message})
      assert Response.tool_calls(response) == [tool_call]
    end

    test "returns empty list when no message" do
      response = build_response(%{message: nil})
      assert Response.tool_calls(response) == []
    end

    test "returns empty list when tool_calls is nil" do
      message = %Message{
        role: :assistant,
        content: [ContentPart.text("Hello")],
        tool_calls: nil
      }

      response = build_response(%{message: message})
      assert Response.tool_calls(response) == []
    end
  end

  describe "usage/1" do
    test "returns usage map" do
      usage = %{input_tokens: 10, output_tokens: 20, total_tokens: 30}
      response = build_response(%{usage: usage})
      assert Response.usage(response) == usage
    end

    test "returns nil when no usage" do
      response = build_response(%{usage: nil})
      assert Response.usage(response) == nil
    end
  end

  describe "reasoning_tokens/1" do
    test "extracts reasoning tokens from usage" do
      usage = %{input_tokens: 10, output_tokens: 20, reasoning_tokens: 64}
      response = build_response(%{usage: usage})
      assert Response.reasoning_tokens(response) == 64
    end

    test "extracts from nested completion_tokens_details" do
      usage = %{
        input_tokens: 10,
        output_tokens: 20,
        completion_tokens_details: %{reasoning_tokens: 128}
      }

      response = build_response(%{usage: usage})
      assert Response.reasoning_tokens(response) == 128
    end

    test "returns 0 when no reasoning tokens" do
      usage = %{input_tokens: 10, output_tokens: 20}
      response = build_response(%{usage: usage})
      assert Response.reasoning_tokens(response) == 0
    end

    test "returns 0 when no usage" do
      response = build_response(%{usage: nil})
      assert Response.reasoning_tokens(response) == 0
    end
  end

  describe "ok?/1" do
    test "returns true when no error" do
      response = build_response(%{error: nil})
      assert Response.ok?(response) == true
    end

    test "returns false when error present" do
      error = %RuntimeError{message: "Something went wrong"}
      response = build_response(%{error: error})
      assert Response.ok?(response) == false
    end
  end

  describe "text_stream/1" do
    test "returns empty list when not streaming" do
      response = build_response(%{stream?: false, stream: nil})
      assert Response.text_stream(response) == []
    end

    test "returns empty list when stream is nil" do
      response = build_response(%{stream?: true, stream: nil})
      assert Response.text_stream(response) == []
    end

    test "filters text chunks from stream" do
      stream = ["Hello", {:tool_call_delta, %{}}, " world", nil]
      response = build_response(%{stream?: true, stream: stream})

      result = response |> Response.text_stream() |> Enum.to_list()
      assert result == ["Hello", " world"]
    end
  end

  describe "object_stream/1" do
    test "returns empty list when not streaming" do
      response = build_response(%{stream?: false, stream: nil})
      assert Response.object_stream(response) == []
    end

    test "filters tool call chunks from stream" do
      delta = {:tool_call_delta, %{index: 0, partial_json: "{}"}}
      start = {:tool_call_start, %{index: 1, id: "call_1", name: "test"}}
      stream = ["text", delta, start, nil]
      response = build_response(%{stream?: true, stream: stream})

      result = response |> Response.object_stream() |> Enum.to_list()
      assert result == [delta, start]
    end
  end

  describe "join_stream/1" do
    test "returns response unchanged when not streaming" do
      response = build_response(%{stream?: false})
      assert {:ok, ^response} = Response.join_stream(response)
    end

    test "returns response unchanged when stream is nil" do
      response = build_response(%{stream?: true, stream: nil})
      assert {:ok, ^response} = Response.join_stream(response)
    end

    test "joins text stream into message" do
      stream = ["Hello", " ", "world", nil]
      context = Context.new([Context.user("Hi")])

      response =
        build_response(%{
          stream?: true,
          stream: stream,
          context: context
        })

      assert {:ok, joined} = Response.join_stream(response)
      assert joined.stream? == false
      assert joined.stream == nil
      assert Response.text(joined) == "Hello world"
    end

    test "collects usage from stream" do
      usage = %{input_tokens: 10, output_tokens: 5, total_tokens: 15}
      stream = ["Hello", {:usage, usage}, nil]
      context = Context.new([Context.user("Hi")])

      response =
        build_response(%{
          stream?: true,
          stream: stream,
          context: context
        })

      assert {:ok, joined} = Response.join_stream(response)
      assert joined.usage == usage
    end

    test "appends assistant message to context" do
      stream = ["Response text", nil]
      user_msg = Context.user("Hi")
      context = Context.new([user_msg])

      response =
        build_response(%{
          stream?: true,
          stream: stream,
          context: context
        })

      assert {:ok, joined} = Response.join_stream(response)
      assert length(joined.context.messages) == 2
      assert Enum.at(joined.context.messages, 1).role == :assistant
    end
  end

  describe "object/1" do
    test "returns object field" do
      obj = %{"name" => "test", "value" => 42}
      response = build_response(%{object: obj})
      assert Response.object(response) == obj
    end

    test "returns nil when no object" do
      response = build_response(%{object: nil})
      assert Response.object(response) == nil
    end
  end

  describe "finish_reason/1" do
    test "returns finish reason" do
      response = build_response(%{finish_reason: :stop})
      assert Response.finish_reason(response) == :stop
    end

    test "returns nil when not set" do
      response = build_response(%{finish_reason: nil})
      assert Response.finish_reason(response) == nil
    end
  end
end
