defmodule ReqLlmNext.ResponseTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Response
  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{Message, ContentPart}
  alias ReqLlmNext.ToolCall
  alias ReqLlmNext.TestModels

  describe "struct definition (Zoi)" do
    test "schema/0 returns Zoi schema" do
      schema = Response.schema()
      assert is_struct(schema)
    end

    test "struct has all expected fields" do
      fields =
        Map.keys(%Response{
          id: "test",
          model: TestModels.openai(),
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
        model: TestModels.openai(),
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
          model: TestModels.openai(),
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
      model: TestModels.openai(),
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

  describe "build/4" do
    test "builds response with model, context, and message" do
      model = TestModels.openai()
      context = Context.new([Context.user("Hello")])
      message = %Message{role: :assistant, content: [ContentPart.text("Hi there!")]}

      response = Response.build(model, context, message)

      assert response.model == model
      assert response.message == message
      assert String.starts_with?(response.id, "resp_")
      assert length(response.context.messages) == 2
      assert Enum.at(response.context.messages, 1) == message
    end

    test "builds response with optional fields" do
      model = TestModels.openai()
      context = Context.new()
      message = %Message{role: :assistant, content: [ContentPart.text("Test")]}
      usage = %{input_tokens: 10, output_tokens: 5}
      provider_meta = %{request_id: "req_123"}

      response =
        Response.build(model, context, message,
          id: "custom_id",
          object: %{"key" => "value"},
          usage: usage,
          finish_reason: :stop,
          provider_meta: provider_meta
        )

      assert response.id == "custom_id"
      assert response.object == %{"key" => "value"}
      assert response.usage == usage
      assert response.finish_reason == :stop
      assert response.provider_meta == provider_meta
    end

    test "builds response with nil message without appending to context" do
      model = TestModels.openai()
      context = Context.new([Context.user("Hello")])

      response = Response.build(model, context, nil)

      assert response.message == nil
      assert length(response.context.messages) == 1
    end

    test "generates unique IDs" do
      model = TestModels.openai()
      context = Context.new()

      response1 = Response.build(model, context, nil)
      response2 = Response.build(model, context, nil)

      assert response1.id != response2.id
    end
  end

  describe "join_stream/1 with tool calls" do
    test "collects tool call deltas into complete tool calls" do
      stream = [
        {:tool_call_delta,
         %{index: 0, id: "call_1", function: %{"name" => "get_weather", "arguments" => ""}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => "{\"loc"}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => "ation\":\"SF\"}"}}},
        {:usage, %{input_tokens: 10, output_tokens: 20}}
      ]

      context = Context.new([Context.user("What's the weather?")])

      response =
        build_response(%{
          stream?: true,
          stream: stream,
          context: context
        })

      assert {:ok, joined} = Response.join_stream(response)
      tool_calls = Response.tool_calls(joined)
      assert length(tool_calls) == 1
      assert hd(tool_calls).function.name == "get_weather"
      assert hd(tool_calls).function.arguments == "{\"location\":\"SF\"}"
    end

    test "handles tool_call_start events" do
      stream = [
        {:tool_call_start, %{index: 0, id: "call_1", name: "search"}},
        {:tool_call_delta, %{index: 0, partial_json: "{\"query\":"}},
        {:tool_call_delta, %{index: 0, partial_json: "\"test\"}"}}
      ]

      context = Context.new([Context.user("Search for test")])

      response =
        build_response(%{
          stream?: true,
          stream: stream,
          context: context
        })

      assert {:ok, joined} = Response.join_stream(response)
      tool_calls = Response.tool_calls(joined)
      assert length(tool_calls) == 1
      assert hd(tool_calls).id == "call_1"
      assert hd(tool_calls).function.name == "search"
      assert hd(tool_calls).function.arguments == "{\"query\":\"test\"}"
    end

    test "handles multiple concurrent tool calls" do
      stream = [
        {:tool_call_delta,
         %{index: 0, id: "call_1", function: %{"name" => "tool_a", "arguments" => ""}}},
        {:tool_call_delta,
         %{index: 1, id: "call_2", function: %{"name" => "tool_b", "arguments" => ""}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => "{}"}}},
        {:tool_call_delta, %{index: 1, function: %{"arguments" => "{\"x\":1}"}}}
      ]

      context = Context.new()

      response =
        build_response(%{
          stream?: true,
          stream: stream,
          context: context
        })

      assert {:ok, joined} = Response.join_stream(response)
      tool_calls = Response.tool_calls(joined)
      assert length(tool_calls) == 2
      assert Enum.at(tool_calls, 0).function.name == "tool_a"
      assert Enum.at(tool_calls, 1).function.name == "tool_b"
    end

    test "handles stream errors" do
      stream = [
        "Hello ",
        {:error, %{message: "Rate limit exceeded"}}
      ]

      context = Context.new()

      response =
        build_response(%{
          stream?: true,
          stream: stream,
          context: context
        })

      assert {:error, error} = Response.join_stream(response)
      assert %ReqLlmNext.Error.API.Stream{} = error
    end

    test "handles empty stream" do
      context = Context.new([Context.user("Hi")])

      response =
        build_response(%{
          stream?: true,
          stream: [],
          context: context
        })

      assert {:ok, joined} = Response.join_stream(response)
      assert joined.message == nil
      assert length(joined.context.messages) == 1
    end
  end

  describe "reasoning_tokens/1 with string keys" do
    test "extracts from string key reasoning_tokens" do
      usage = %{"input_tokens" => 10, "output_tokens" => 20, "reasoning_tokens" => 32}
      response = build_response(%{usage: usage})
      assert Response.reasoning_tokens(response) == 32
    end

    test "extracts from string key reasoning" do
      usage = %{"input_tokens" => 10, "output_tokens" => 20, "reasoning" => 48}
      response = build_response(%{usage: usage})
      assert Response.reasoning_tokens(response) == 48
    end

    test "extracts from nested string key completion_tokens_details" do
      usage = %{
        "input_tokens" => 10,
        "output_tokens" => 20,
        "completion_tokens_details" => %{"reasoning_tokens" => 96}
      }

      response = build_response(%{usage: usage})
      assert Response.reasoning_tokens(response) == 96
    end
  end

  describe "text/1 filters non-text content" do
    test "ignores image_url content parts" do
      message = %Message{
        role: :assistant,
        content: [
          ContentPart.text("Here's the result: "),
          ContentPart.image_url("https://example.com/image.png"),
          ContentPart.text("Done!")
        ]
      }

      response = build_response(%{message: message})
      assert Response.text(response) == "Here's the result: Done!"
    end

    test "ignores thinking content parts" do
      message = %Message{
        role: :assistant,
        content: [
          %ContentPart{type: :thinking, text: "Let me think..."},
          ContentPart.text("The answer is 42.")
        ]
      }

      response = build_response(%{message: message})
      assert Response.text(response) == "The answer is 42."
    end
  end

  describe "thinking/1 with multiple thinking parts" do
    test "concatenates multiple thinking parts" do
      message = %Message{
        role: :assistant,
        content: [
          %ContentPart{type: :thinking, text: "First thought. "},
          %ContentPart{type: :thinking, text: "Second thought."},
          ContentPart.text("The answer is 42.")
        ]
      }

      response = build_response(%{message: message})
      assert Response.thinking(response) == "First thought. Second thought."
    end
  end

  describe "Jason.Encoder" do
    test "encodes response to JSON excluding stream" do
      message = %Message{role: :assistant, content: [ContentPart.text("Hello")]}

      response =
        build_response(%{
          message: message,
          stream?: true,
          stream: Stream.repeatedly(fn -> "chunk" end),
          usage: %{input_tokens: 10, output_tokens: 5}
        })

      json = Jason.encode!(response)
      decoded = Jason.decode!(json)

      assert decoded["id"] == response.id
      assert decoded["usage"] == %{"input_tokens" => 10, "output_tokens" => 5}
      refute Map.has_key?(decoded, "stream")
    end
  end
end
