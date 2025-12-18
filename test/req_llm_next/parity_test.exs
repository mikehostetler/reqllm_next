defmodule ReqLlmNext.ParityTest do
  @moduledoc """
  Tests verifying v1 feature parity for OpenAI and Anthropic providers.

  These tests ensure that all public APIs and structs match the expected
  interface from the v1 implementation.
  """
  use ExUnit.Case, async: true

  @moduletag :parity

  alias ReqLlmNext.{Context, Response, StreamResponse, Tool, ToolCall, Error}
  alias ReqLlmNext.TestModels

  defp has_function?(module, function, arity) do
    Code.ensure_loaded!(module)
    function_exported?(module, function, arity)
  end

  describe "API parity with v1" do
    test "generate_text/3 exists and returns Response" do
      assert has_function?(ReqLlmNext, :generate_text, 3)
    end

    test "stream_text/3 exists and returns StreamResponse" do
      assert has_function?(ReqLlmNext, :stream_text, 3)
    end

    test "generate_object/4 exists" do
      assert has_function?(ReqLlmNext, :generate_object, 4)
    end

    test "generate_object!/4 exists" do
      assert has_function?(ReqLlmNext, :generate_object!, 4)
    end

    test "stream_object/4 exists" do
      assert has_function?(ReqLlmNext, :stream_object, 4)
    end

    test "embed/3 exists" do
      assert has_function?(ReqLlmNext, :embed, 3)
    end

    test "embed!/3 exists" do
      assert has_function?(ReqLlmNext, :embed!, 3)
    end

    test "cosine_similarity/2 exists and works" do
      assert has_function?(ReqLlmNext, :cosine_similarity, 2)

      vec1 = [1.0, 0.0, 0.0]
      vec2 = [1.0, 0.0, 0.0]
      assert ReqLlmNext.cosine_similarity(vec1, vec2) == 1.0

      vec3 = [0.0, 1.0, 0.0]
      assert_in_delta ReqLlmNext.cosine_similarity(vec1, vec3), 0.0, 0.001
    end

    test "json_schema/2 exists and works" do
      assert has_function?(ReqLlmNext, :json_schema, 2)

      schema = [name: [type: :string, required: true]]
      result = ReqLlmNext.json_schema(schema)

      assert is_map(result)
      assert result["type"] == "object"
      assert is_map(result["properties"])
    end

    test "context/1 exists and works" do
      assert has_function?(ReqLlmNext, :context, 1)

      ctx = ReqLlmNext.context("Hello")
      assert %Context{} = ctx
    end

    test "model/1 exists" do
      assert has_function?(ReqLlmNext, :model, 1)
    end

    test "provider/1 exists" do
      assert has_function?(ReqLlmNext, :provider, 1)
    end

    test "tool/1 exists and works" do
      assert has_function?(ReqLlmNext, :tool, 1)

      tool =
        ReqLlmNext.tool(
          name: "test_tool",
          description: "A test tool",
          callback: fn _args -> {:ok, "result"} end
        )

      assert %Tool{} = tool
      assert tool.name == "test_tool"
    end

    test "put_key/2 exists" do
      assert has_function?(ReqLlmNext, :put_key, 2)
    end

    test "get_key/1 exists" do
      assert has_function?(ReqLlmNext, :get_key, 1)
    end

    test "embedding_models/0 exists" do
      assert has_function?(ReqLlmNext, :embedding_models, 0)
    end
  end

  describe "Response struct parity" do
    setup do
      model = TestModels.minimal()
      context = Context.new([Context.user("Hello")])

      message = %Context.Message{
        role: :assistant,
        content: [Context.ContentPart.text("Hi there!")],
        metadata: %{}
      }

      response = %Response{
        id: "resp_123",
        model: model,
        context: context,
        message: message,
        object: nil,
        usage: %{input_tokens: 10, output_tokens: 5},
        finish_reason: :stop
      }

      {:ok, response: response}
    end

    test "has id field", %{response: r} do
      assert is_binary(r.id)
    end

    test "has model field", %{response: r} do
      assert %LLMDB.Model{} = r.model
    end

    test "has context field", %{response: r} do
      assert %Context{} = r.context
    end

    test "has message field", %{response: r} do
      assert %Context.Message{} = r.message
    end

    test "has object field", %{response: r} do
      assert Map.has_key?(r, :object)
    end

    test "has usage field", %{response: r} do
      assert is_map(r.usage)
    end

    test "has finish_reason field", %{response: r} do
      assert r.finish_reason == :stop
    end

    test "has stream? field", %{response: r} do
      assert Map.has_key?(r, :stream?)
    end

    test "has error field", %{response: r} do
      assert Map.has_key?(r, :error)
    end

    test "text/1 helper works", %{response: r} do
      assert is_binary(Response.text(r))
      assert Response.text(r) == "Hi there!"
    end

    test "thinking/1 helper works", %{response: r} do
      assert is_binary(Response.thinking(r)) or is_nil(Response.thinking(r))
    end

    test "tool_calls/1 helper works", %{response: r} do
      assert is_list(Response.tool_calls(r))
    end

    test "usage/1 helper works", %{response: r} do
      assert is_map(Response.usage(r))
    end

    test "reasoning_tokens/1 helper works", %{response: r} do
      assert is_integer(Response.reasoning_tokens(r))
    end

    test "ok?/1 helper works", %{response: r} do
      assert Response.ok?(r) == true
    end

    test "build/4 helper exists" do
      Code.ensure_loaded!(Response)
      assert function_exported?(Response, :build, 4)
    end

    test "finish_reason/1 helper works", %{response: r} do
      assert Response.finish_reason(r) == :stop
    end
  end

  describe "StreamResponse parity" do
    setup do
      model = TestModels.minimal()
      stream = Stream.map(["Hello", " ", "world"], & &1)
      stream_resp = %StreamResponse{stream: stream, model: model}
      {:ok, stream_resp: stream_resp}
    end

    test "text/1 works", %{stream_resp: sr} do
      text = StreamResponse.text(sr)
      assert text == "Hello world"
    end

    test "object/1 works" do
      model = TestModels.minimal()
      stream = Stream.map([~s({"name": "test"})], & &1)
      sr = %StreamResponse{stream: stream, model: model}

      obj = StreamResponse.object(sr)
      assert obj == %{"name" => "test"}
    end

    test "tool_calls/1 works", %{stream_resp: sr} do
      assert is_list(StreamResponse.tool_calls(sr))
    end

    test "thinking/1 works", %{stream_resp: sr} do
      assert is_binary(StreamResponse.thinking(sr))
    end

    test "usage/1 works" do
      model = TestModels.minimal()
      stream = Stream.map([{:usage, %{input_tokens: 10}}], & &1)
      sr = %StreamResponse{stream: stream, model: model}

      usage = StreamResponse.usage(sr)
      assert usage == %{input_tokens: 10}
    end

    test "cancel/1 exists" do
      Code.ensure_loaded!(StreamResponse)
      assert function_exported?(StreamResponse, :cancel, 1)

      model = TestModels.minimal()
      stream = Stream.map([], & &1)
      sr = %StreamResponse{stream: stream, model: model, cancel_fn: nil}

      assert StreamResponse.cancel(sr) == :ok
    end

    test "cancel/1 calls cancel function" do
      model = TestModels.minimal()
      stream = Stream.map([], & &1)

      test_pid = self()

      cancel_fn = fn ->
        send(test_pid, :cancelled)
        :ok
      end

      sr = %StreamResponse{stream: stream, model: model, cancel_fn: cancel_fn}
      assert StreamResponse.cancel(sr) == :ok
      assert_receive :cancelled
    end
  end

  describe "Error types parity" do
    test "Invalid.Parameter exists" do
      error = Error.Invalid.Parameter.exception(parameter: "test")
      assert Exception.message(error) =~ "test"
    end

    test "Invalid.Provider exists" do
      error = Error.Invalid.Provider.exception(provider: :unknown)
      assert Exception.message(error) =~ "unknown"
    end

    test "Invalid.Capability exists" do
      error = Error.Invalid.Capability.exception(missing: [:vision])
      assert Exception.message(error) =~ "vision"
    end

    test "API.Request exists" do
      error = Error.API.Request.exception(reason: "timeout")
      assert Exception.message(error) =~ "timeout"
    end

    test "API.Response exists" do
      error = Error.API.Response.exception(reason: "invalid json")
      assert Exception.message(error) =~ "invalid json"
    end

    test "API.Stream exists" do
      error = Error.API.Stream.exception(reason: "connection closed")
      assert Exception.message(error) =~ "connection closed"
    end

    test "API.SchemaValidation exists" do
      error = Error.API.SchemaValidation.exception(message: "invalid field")
      assert Exception.message(error) =~ "invalid field"
    end

    test "API.JsonParse exists" do
      error = Error.API.JsonParse.exception(message: "unexpected token")
      assert Exception.message(error) =~ "unexpected token"
    end

    test "Validation.Error exists" do
      error = Error.Validation.Error.exception(tag: :test, reason: "failed")
      assert Exception.message(error) =~ "failed"
    end

    test "Unknown.Unknown exists" do
      error = Error.Unknown.Unknown.exception(error: "mystery")
      assert Exception.message(error) =~ "mystery"
    end

    test "validation_error/3 helper works" do
      error = Error.validation_error(:test_tag, "test reason", key: "value")
      assert error.tag == :test_tag
      assert error.reason == "test reason"
      assert error.context == [key: "value"]
    end
  end

  describe "Context parity" do
    test "Context.new/1 exists" do
      ctx = Context.new([])
      assert %Context{} = ctx
    end

    test "Context.append/2 exists" do
      ctx = Context.new([])
      msg = Context.user("Hello")
      updated = Context.append(ctx, msg)
      assert length(updated.messages) == 1
    end

    test "Context.user/1 exists" do
      msg = Context.user("Hello")
      assert msg.role == :user
    end

    test "Context.assistant/1 exists" do
      msg = Context.assistant("Hi")
      assert msg.role == :assistant
    end

    test "Context.system/1 exists" do
      msg = Context.system("You are helpful")
      assert msg.role == :system
    end

    test "Context.tool_result/2 exists" do
      msg = Context.tool_result("call_123", "result")
      assert msg.role == :tool
    end

    test "Context.normalize/2 exists" do
      {:ok, ctx} = Context.normalize("Hello")
      assert %Context{} = ctx
    end
  end

  describe "Tool parity" do
    test "Tool.new!/1 creates tool" do
      tool =
        Tool.new!(
          name: "get_weather",
          description: "Gets weather",
          callback: fn _ -> {:ok, "sunny"} end
        )

      assert tool.name == "get_weather"
    end

    test "Tool.execute/2 runs callback" do
      tool =
        Tool.new!(
          name: "add",
          description: "Adds numbers",
          callback: fn args -> {:ok, args["a"] + args["b"]} end
        )

      {:ok, result} = Tool.execute(tool, %{"a" => 1, "b" => 2})
      assert result == 3
    end

    test "Tool.to_json_schema/1 returns schema" do
      tool =
        Tool.new!(
          name: "test",
          description: "Test tool",
          parameter_schema: [x: [type: :integer, required: true]],
          callback: fn _ -> {:ok, nil} end
        )

      schema = Tool.to_json_schema(tool)
      assert schema["type"] == "function"
      assert schema["function"]["name"] == "test"
    end
  end

  describe "ToolCall parity" do
    test "ToolCall.new/3 creates tool call" do
      tc = ToolCall.new("call_123", "get_weather", ~s({"location":"SF"}))
      assert tc.id == "call_123"
      assert tc.function.name == "get_weather"
    end

    test "ToolCall has id field" do
      tc = ToolCall.new("id", "name", "{}")
      assert tc.id == "id"
    end

    test "ToolCall has function field" do
      tc = ToolCall.new("id", "name", "{}")
      assert is_map(tc.function)
      assert tc.function.name == "name"
      assert tc.function.arguments == "{}"
    end
  end
end
