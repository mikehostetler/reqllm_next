defmodule ReqLlmNextTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context

  describe "put_key/2 and get_key/1" do
    test "stores and retrieves atom keys from application config" do
      assert :ok = ReqLlmNext.put_key(:test_api_key, "test-value-123")
      assert ReqLlmNext.get_key(:test_api_key) == "test-value-123"
    end

    test "get_key/1 with string key reads from environment" do
      System.put_env("REQ_LLM_NEXT_TEST_KEY", "env-value")
      assert ReqLlmNext.get_key("REQ_LLM_NEXT_TEST_KEY") == "env-value"
      System.delete_env("REQ_LLM_NEXT_TEST_KEY")
    end

    test "get_key/1 returns nil for missing keys" do
      assert ReqLlmNext.get_key(:nonexistent_key_12345) == nil
    end

    test "put_key/2 raises for non-atom keys" do
      assert_raise ArgumentError, ~r/expects an atom key/, fn ->
        ReqLlmNext.put_key("string_key", "value")
      end
    end
  end

  describe "context/1" do
    test "creates context from string prompt" do
      ctx = ReqLlmNext.context("Hello!")

      assert %Context{} = ctx
      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end

    test "creates context from message list" do
      messages = [
        Context.system("You are helpful"),
        Context.user("Hello!")
      ]

      ctx = ReqLlmNext.context(messages)

      assert length(ctx.messages) == 2
      assert Enum.at(ctx.messages, 0).role == :system
      assert Enum.at(ctx.messages, 1).role == :user
    end

    test "creates context from single message" do
      msg = Context.user("Hello!")
      ctx = ReqLlmNext.context(msg)

      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end
  end

  describe "provider/1" do
    test "returns known provider module" do
      assert {:ok, ReqLlmNext.Providers.OpenAI} = ReqLlmNext.provider(:openai)
      assert {:ok, ReqLlmNext.Providers.Anthropic} = ReqLlmNext.provider(:anthropic)
    end

    test "returns error for unknown provider" do
      assert {:error, {:unknown_provider, :unknown_provider}} =
               ReqLlmNext.provider(:unknown_provider)
    end
  end

  describe "model/1" do
    test "resolves string model spec" do
      assert {:ok, model} = ReqLlmNext.model("openai:gpt-4o-mini")
      assert model.provider == :openai
      assert model.id == "gpt-4o-mini"
    end

    test "passes through LLMDB.Model struct" do
      {:ok, original} = LLMDB.model("openai:gpt-4o")
      assert {:ok, ^original} = ReqLlmNext.model(original)
    end

    test "resolves tuple format with options" do
      assert {:ok, model} = ReqLlmNext.model({:openai, "gpt-4o-mini", temperature: 0.7})
      assert model.provider == :openai
      assert model.id == "gpt-4o-mini"
    end

    test "resolves tuple format with keyword list" do
      assert {:ok, model} = ReqLlmNext.model({:openai, id: "gpt-4o-mini"})
      assert model.provider == :openai
    end

    test "returns error for invalid spec" do
      assert {:error, _} = ReqLlmNext.model(:invalid)
    end
  end

  describe "generate_text/3" do
    test "returns Response struct using buffered stream with fixture" do
      {:ok, result} =
        ReqLlmNext.generate_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %ReqLlmNext.Response{} = result
      text = ReqLlmNext.Response.text(result)
      assert String.length(text) > 0
      assert result.model.id == "gpt-4o-mini"
    end

    test "delegates to Executor" do
      {:ok, result} = ReqLlmNext.generate_text("openai:gpt-4o", "Test", fixture: "basic")

      assert %ReqLlmNext.Response{} = result
      assert is_binary(ReqLlmNext.Response.text(result))
      assert result.model.provider == :openai
    end
  end

  describe "stream_text/3" do
    test "returns StreamResponse" do
      {:ok, resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %ReqLlmNext.StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
    end

    test "stream produces text chunks" do
      {:ok, resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      chunks = Enum.to_list(resp.stream)
      refute Enum.empty?(chunks)
    end

    test "works with anthropic" do
      {:ok, resp} =
        ReqLlmNext.stream_text("anthropic:claude-sonnet-4-20250514", "Hello!",
          fixture: "basic",
          max_tokens: 50
        )

      assert resp.model.provider == :anthropic
    end

    test "returns error for invalid model" do
      assert {:error, _} = ReqLlmNext.stream_text("openai:nonexistent", "Hello!", [])
    end
  end

  describe "stream_object/4" do
    @person_schema [
      name: [type: :string, required: true],
      age: [type: :integer, required: true]
    ]

    test "returns StreamResponse with object stream" do
      {:ok, resp} =
        ReqLlmNext.stream_object(
          "openai:gpt-4o-mini",
          "Generate a person",
          @person_schema,
          fixture: "person_object"
        )

      assert %ReqLlmNext.StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
    end

    test "stream produces valid JSON chunks" do
      {:ok, resp} =
        ReqLlmNext.stream_object(
          "openai:gpt-4o-mini",
          "Generate a person",
          @person_schema,
          fixture: "person_object"
        )

      text = ReqLlmNext.StreamResponse.text(resp)
      {:ok, object} = Jason.decode(text)
      assert is_binary(object["name"])
      assert is_integer(object["age"])
    end

    test "returns error for invalid model" do
      assert {:error, _} =
               ReqLlmNext.stream_object("openai:nonexistent", "Generate", @person_schema, [])
    end
  end

  describe "generate_object/4" do
    @person_schema [
      name: [type: :string, required: true],
      age: [type: :integer, required: true]
    ]

    test "returns Response with parsed object" do
      {:ok, resp} =
        ReqLlmNext.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %ReqLlmNext.Response{} = resp
      assert is_map(resp.object)
      assert is_binary(resp.object["name"])
      assert is_integer(resp.object["age"])
    end

    test "returns error for invalid model" do
      assert {:error, _} =
               ReqLlmNext.generate_object("openai:nonexistent", "Generate", @person_schema, [])
    end

    test "returns error for invalid schema" do
      result =
        ReqLlmNext.generate_object(
          "openai:gpt-4o-mini",
          "Generate",
          "not a valid schema",
          []
        )

      assert {:error, {:invalid_schema, _}} = result
    end
  end

  describe "generate_object!/4" do
    @person_schema [
      name: [type: :string, required: true],
      age: [type: :integer, required: true]
    ]

    test "returns Response on success" do
      resp =
        ReqLlmNext.generate_object!(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %ReqLlmNext.Response{} = resp
      assert is_map(resp.object)
    end

    test "raises on model not found error" do
      assert_raise ArgumentError, fn ->
        ReqLlmNext.generate_object!("openai:nonexistent", "Generate", @person_schema, [])
      end
    end
  end

  describe "embed/3" do
    test "returns error for unknown model" do
      result = ReqLlmNext.embed("openai:nonexistent-model", "Hello world", [])
      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end

    test "returns error for empty input" do
      result = ReqLlmNext.embed("openai:text-embedding-3-small", "", [])
      assert {:error, %ReqLlmNext.Error.Invalid.Parameter{}} = result
    end

    test "raises for non-embedding model" do
      assert_raise ReqLlmNext.Error.Invalid.Capability, fn ->
        ReqLlmNext.embed("openai:gpt-4o-mini", "Hello", [])
      end
    end
  end

  describe "embed!/3" do
    test "raises on error" do
      assert_raise ReqLlmNext.Error.Invalid.Parameter, fn ->
        ReqLlmNext.embed!("openai:text-embedding-3-small", "", [])
      end
    end
  end

  describe "cosine_similarity/2" do
    test "returns 1.0 for identical vectors" do
      vec = [1.0, 0.0, 0.0]
      assert ReqLlmNext.cosine_similarity(vec, vec) == 1.0
    end

    test "returns 0.0 for orthogonal vectors" do
      vec1 = [1.0, 0.0]
      vec2 = [0.0, 1.0]
      assert ReqLlmNext.cosine_similarity(vec1, vec2) == 0.0
    end

    test "returns -1.0 for opposite vectors" do
      vec1 = [1.0, 0.0]
      vec2 = [-1.0, 0.0]
      assert ReqLlmNext.cosine_similarity(vec1, vec2) == -1.0
    end

    test "returns 0.0 for zero magnitude vector" do
      vec1 = [0.0, 0.0]
      vec2 = [1.0, 0.0]
      assert ReqLlmNext.cosine_similarity(vec1, vec2) == 0.0
    end
  end

  describe "embedding_models/0" do
    test "returns list of embedding model specs" do
      models = ReqLlmNext.embedding_models()
      assert is_list(models)
      assert Enum.all?(models, &is_binary/1)
    end
  end

  describe "tool/1" do
    test "creates Tool struct from options" do
      tool =
        ReqLlmNext.tool(
          name: "get_weather",
          description: "Get weather for location",
          callback: fn _args -> {:ok, "sunny"} end
        )

      assert %ReqLlmNext.Tool{} = tool
      assert tool.name == "get_weather"
      assert tool.description == "Get weather for location"
    end

    test "creates Tool with parameter schema" do
      tool =
        ReqLlmNext.tool(
          name: "add",
          description: "Add numbers",
          parameter_schema: [
            a: [type: :integer, required: true],
            b: [type: :integer, required: true]
          ],
          callback: fn args -> {:ok, args["a"] + args["b"]} end
        )

      assert tool.name == "add"
      assert tool.parameter_schema != nil
    end

    test "raises for missing required options" do
      assert_raise ArgumentError, fn ->
        ReqLlmNext.tool(name: "test")
      end
    end
  end

  describe "json_schema/2" do
    test "converts NimbleOptions schema to JSON Schema" do
      nimble = [
        name: [type: :string, required: true, doc: "Person name"],
        age: [type: :integer]
      ]

      result = ReqLlmNext.json_schema(nimble, name: "Person")

      assert result["title"] == "Person"
      assert result["type"] == "object"
      assert result["properties"]["name"]["type"] == "string"
      assert result["properties"]["age"]["type"] == "integer"
      assert "name" in result["required"]
    end

    test "works without options" do
      nimble = [value: [type: :string]]
      result = ReqLlmNext.json_schema(nimble)

      assert result["type"] == "object"
      assert result["properties"]["value"]["type"] == "string"
    end
  end

  describe "model/1 edge cases" do
    test "returns error for tuple with keyword list missing id" do
      assert {:error, {:invalid_model_spec, [not_id: "value"]}} =
               ReqLlmNext.model({:openai, not_id: "value"})
    end
  end
end
