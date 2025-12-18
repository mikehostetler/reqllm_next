defmodule ReqLlmNext.StreamResponseTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.StreamResponse
  alias ReqLlmNext.ToolCall

  defp mock_model do
    %LLMDB.Model{id: "test-model", provider: :openai}
  end

  describe "text/1" do
    test "extracts text from stream of strings" do
      stream = ["Hello", " ", "world", "!"]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.text(resp) == "Hello world!"
    end

    test "filters out non-text items" do
      stream = ["Hello", {:usage, %{tokens: 10}}, " world", {:meta, %{done: true}}]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.text(resp) == "Hello world"
    end

    test "filters out tool call deltas" do
      stream = [
        "Checking",
        {:tool_call_delta, %{index: 0, id: "call_1", function: %{"name" => "test"}}},
        " weather"
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.text(resp) == "Checking weather"
    end

    test "filters out thinking tuples" do
      stream = [
        {:thinking, "Let me think..."},
        "The answer is 42"
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.text(resp) == "The answer is 42"
    end

    test "returns empty string for stream with no text" do
      stream = [{:usage, %{}}, {:meta, %{}}]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.text(resp) == ""
    end

    test "handles empty stream" do
      resp = %StreamResponse{stream: [], model: mock_model()}

      assert StreamResponse.text(resp) == ""
    end
  end

  describe "thinking/1" do
    test "extracts thinking content from stream" do
      stream = [
        {:thinking, "First thought"},
        {:thinking, " and second"},
        "Final answer"
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.thinking(resp) == "First thought and second"
    end

    test "handles thinking_start tuples" do
      stream = [
        {:thinking_start, %{id: "thought_1"}},
        {:thinking, "My reasoning"},
        "Answer"
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.thinking(resp) == "My reasoning"
    end

    test "returns empty string when no thinking" do
      stream = ["Just text", {:usage, %{}}]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.thinking(resp) == ""
    end

    test "handles empty stream" do
      resp = %StreamResponse{stream: [], model: mock_model()}

      assert StreamResponse.thinking(resp) == ""
    end
  end

  describe "usage/1" do
    test "extracts usage metadata" do
      usage_data = %{prompt_tokens: 10, completion_tokens: 20, total_tokens: 30}
      stream = ["Hello", {:usage, usage_data}]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.usage(resp) == usage_data
    end

    test "returns nil when no usage" do
      stream = ["Hello", "world"]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.usage(resp) == nil
    end

    test "returns first usage tuple found" do
      stream = [
        {:usage, %{first: true}},
        {:usage, %{second: true}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.usage(resp) == %{first: true}
    end

    test "handles empty stream" do
      resp = %StreamResponse{stream: [], model: mock_model()}

      assert StreamResponse.usage(resp) == nil
    end
  end

  describe "object/1" do
    test "parses JSON from text stream" do
      stream = [~s({"name":), ~s("John","age":30})]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.object(resp) == %{"name" => "John", "age" => 30}
    end

    test "returns nil for invalid JSON" do
      stream = ["not valid json"]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.object(resp) == nil
    end

    test "returns nil for empty stream" do
      resp = %StreamResponse{stream: [], model: mock_model()}

      assert StreamResponse.object(resp) == nil
    end

    test "handles complex nested JSON" do
      json = ~s({"user":{"name":"Jane","roles":["admin","user"]},"active":true})
      stream = [json]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      obj = StreamResponse.object(resp)
      assert obj["user"]["name"] == "Jane"
      assert obj["user"]["roles"] == ["admin", "user"]
      assert obj["active"] == true
    end
  end

  describe "tool_calls/1" do
    test "assembles tool calls from deltas with initial id" do
      stream = [
        {:tool_call_delta,
         %{index: 0, id: "call_1", type: "function", function: %{"name" => "get_weather"}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => ~s({"city":)}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => ~s("NYC"})}}},
        {:usage, %{}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert length(calls) == 1
      tc = hd(calls)
      assert tc.id == "call_1"
      assert ToolCall.name(tc) == "get_weather"
      assert ToolCall.args_json(tc) == ~s({"city":"NYC"})
    end

    test "assembles multiple tool calls" do
      stream = [
        {:tool_call_delta, %{index: 0, id: "call_1", function: %{"name" => "add"}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => ~s({"a":1,"b":2})}}},
        {:tool_call_delta, %{index: 1, id: "call_2", function: %{"name" => "multiply"}}},
        {:tool_call_delta, %{index: 1, function: %{"arguments" => ~s({"x":3,"y":4})}}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert length(calls) == 2
      assert Enum.at(calls, 0).id == "call_1"
      assert Enum.at(calls, 1).id == "call_2"
    end

    test "handles tool_call_start events (Anthropic style)" do
      stream = [
        {:tool_call_start, %{index: 0, id: "toolu_1", name: "search"}},
        {:tool_call_delta, %{index: 0, partial_json: ~s({"query":)}},
        {:tool_call_delta, %{index: 0, partial_json: ~s("hello"})}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert length(calls) == 1
      tc = hd(calls)
      assert tc.id == "toolu_1"
      assert ToolCall.name(tc) == "search"
      assert ToolCall.args_json(tc) == ~s({"query":"hello"})
    end

    test "merges id from later delta when nil initially" do
      stream = [
        {:tool_call_delta, %{index: 0, id: nil, function: %{"name" => "test"}}},
        {:tool_call_delta, %{index: 0, id: "late_id"}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert length(calls) == 1
      assert hd(calls).id == "late_id"
    end

    test "returns empty list when no tool calls" do
      stream = ["Hello", {:usage, %{}}]
      resp = %StreamResponse{stream: stream, model: mock_model()}

      assert StreamResponse.tool_calls(resp) == []
    end

    test "handles empty stream" do
      resp = %StreamResponse{stream: [], model: mock_model()}

      assert StreamResponse.tool_calls(resp) == []
    end

    test "sorts tool calls by index" do
      stream = [
        {:tool_call_delta, %{index: 2, id: "call_3", function: %{"name" => "c"}}},
        {:tool_call_delta, %{index: 2, function: %{"arguments" => "{}"}}},
        {:tool_call_delta, %{index: 0, id: "call_1", function: %{"name" => "a"}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => "{}"}}},
        {:tool_call_delta, %{index: 1, id: "call_2", function: %{"name" => "b"}}},
        {:tool_call_delta, %{index: 1, function: %{"arguments" => "{}"}}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert Enum.map(calls, & &1.id) == ["call_1", "call_2", "call_3"]
    end

    test "handles delta without function map" do
      stream = [
        {:tool_call_delta, %{index: 0, id: "call_1", function: %{"name" => "test"}}},
        {:tool_call_delta, %{index: 0, other: "data"}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert length(calls) == 1
    end

    test "tool_call_start overrides existing values" do
      stream = [
        {:tool_call_delta, %{index: 0, function: %{"name" => "old_name"}}},
        {:tool_call_start, %{index: 0, id: "new_id", name: "new_name"}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => "{}"}}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert length(calls) == 1
      tc = hd(calls)
      assert tc.id == "new_id"
      assert ToolCall.name(tc) == "new_name"
    end

    test "handles init with id but no function name" do
      stream = [
        {:tool_call_delta, %{index: 0, id: "call_1", type: "function", function: %{}}},
        {:tool_call_delta, %{index: 0, function: %{"name" => "delayed_name"}}},
        {:tool_call_delta, %{index: 0, function: %{"arguments" => "{}"}}}
      ]

      resp = %StreamResponse{stream: stream, model: mock_model()}
      calls = StreamResponse.tool_calls(resp)

      assert length(calls) == 1
      assert ToolCall.name(hd(calls)) == "delayed_name"
    end
  end

  describe "cancel/1" do
    test "returns :ok when no cancel_fn" do
      resp = %StreamResponse{stream: [], model: mock_model(), cancel_fn: nil}

      assert StreamResponse.cancel(resp) == :ok
    end

    test "calls cancel_fn when present" do
      test_pid = self()

      cancel_fn = fn ->
        send(test_pid, :cancelled)
        :ok
      end

      resp = %StreamResponse{stream: [], model: mock_model(), cancel_fn: cancel_fn}

      assert StreamResponse.cancel(resp) == :ok
      assert_received :cancelled
    end
  end
end
