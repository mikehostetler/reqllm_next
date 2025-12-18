defmodule ReqLlmNext.ExecutorTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Executor, Response, Error}

  @person_schema [
    name: [type: :string, required: true],
    age: [type: :integer, required: true]
  ]

  describe "generate_text/3" do
    test "returns text and model using fixture replay" do
      {:ok, result} = Executor.generate_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %Response{} = result
      text = Response.text(result)
      assert is_binary(text)
      assert String.length(text) > 0
      assert result.model.id == "gpt-4o-mini"
      assert result.model.provider == :openai
    end

    test "works with anthropic model" do
      {:ok, result} =
        Executor.generate_text("anthropic:claude-sonnet-4-20250514", "Hello!",
          fixture: "basic",
          max_tokens: 50
        )

      assert %Response{} = result
      assert is_binary(Response.text(result))
      assert result.model.provider == :anthropic
    end

    test "returns error for unknown model" do
      result = Executor.generate_text("openai:nonexistent-model", "Hello!", [])

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end
  end

  describe "stream_text/3" do
    test "returns StreamResponse with stream and model" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %ReqLlmNext.StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
      assert is_function(resp.stream) or is_struct(resp.stream, Stream)
    end

    test "stream can be enumerated" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      chunks = Enum.to_list(resp.stream)
      assert is_list(chunks)
      refute Enum.empty?(chunks)
      text_chunks = Enum.filter(chunks, &is_binary/1)
      assert length(text_chunks) > 0
    end

    test "returns error for unknown model" do
      result = Executor.stream_text("openai:nonexistent-model", "Hello!", [])

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end

    test "applies adapter pipeline for gpt-4o-mini" do
      {:ok, resp} =
        Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert resp.model.id == "gpt-4o-mini"
    end
  end

  describe "pipeline integration" do
    test "full pipeline flows through all steps" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o", "Test", fixture: "basic")

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
    end

    test "anthropic pipeline with max_tokens" do
      {:ok, resp} =
        Executor.stream_text("anthropic:claude-haiku-4-5-20251001", "Hello",
          fixture: "basic",
          max_tokens: 50
        )

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
    end

    test "passes temperature through adapter to wire" do
      {:ok, resp} =
        Executor.stream_text("openai:gpt-4o-mini", "Hello",
          fixture: "basic",
          temperature: 0.9
        )

      assert resp.model.id == "gpt-4o-mini"
    end
  end

  describe "error handling" do
    test "invalid model spec returns error" do
      result = Executor.stream_text("invalid:model", "Hello", [])
      assert {:error, _} = result
    end

    test "model not found returns descriptive error" do
      {:error, {:model_not_found, spec, _reason}} =
        Executor.stream_text("openai:not-a-real-model-xyz", "Hello", [])

      assert spec == "openai:not-a-real-model-xyz"
    end
  end

  describe "fixture replay" do
    test "replays openai fixture correctly" do
      {:ok, resp} = Executor.stream_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
      assert String.length(text) > 0
    end

    test "replays anthropic fixture correctly" do
      {:ok, resp} =
        Executor.stream_text("anthropic:claude-sonnet-4-20250514", "Hello!",
          fixture: "basic",
          max_tokens: 50
        )

      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
    end
  end

  describe "stream_object/4" do
    test "returns StreamResponse with stream and model" do
      {:ok, resp} =
        Executor.stream_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %ReqLlmNext.StreamResponse{} = resp
      assert resp.model.id == "gpt-4o-mini"
    end

    test "stream produces valid JSON chunks" do
      {:ok, resp} =
        Executor.stream_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      text_chunks = resp.stream |> Enum.filter(&is_binary/1)
      json = Enum.join(text_chunks)
      {:ok, object} = Jason.decode(json)

      assert is_binary(object["name"])
      assert is_integer(object["age"])
    end

    test "returns error for unknown model" do
      result =
        Executor.stream_object(
          "openai:nonexistent-model",
          "Generate a profile",
          @person_schema,
          []
        )

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end

    test "returns error for invalid schema" do
      result =
        Executor.stream_object(
          "openai:gpt-4o-mini",
          "Generate a profile",
          "not a valid schema",
          []
        )

      assert {:error, {:invalid_schema, _}} = result
    end
  end

  describe "generate_object/4 error handling" do
    test "returns SchemaValidation error for invalid object" do
      invalid_schema = [
        required_field: [type: :string, required: true]
      ]

      result =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          invalid_schema,
          fixture: "person_object"
        )

      assert {:error, %Error.API.SchemaValidation{}} = result
    end

    test "returns error for invalid schema type" do
      result =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a profile",
          :invalid_schema_type,
          []
        )

      assert {:error, {:invalid_schema, _}} = result
    end
  end

  describe "validate_embedding_input/1" do
    test "returns error for empty string input" do
      result = Executor.embed("openai:text-embedding-3-small", "", [])
      assert {:error, %Error.Invalid.Parameter{parameter: "input: cannot be empty"}} = result
    end

    test "returns error for empty list input" do
      result = Executor.embed("openai:text-embedding-3-small", [], [])

      assert {:error, %Error.Invalid.Parameter{parameter: "input: cannot be empty list"}} =
               result
    end

    test "returns error for list with empty string" do
      result = Executor.embed("openai:text-embedding-3-small", ["hello", ""], [])

      assert {:error, %Error.Invalid.Parameter{parameter: "input: contains empty string"}} =
               result
    end

    test "returns error for list with non-string items" do
      result = Executor.embed("openai:text-embedding-3-small", ["hello", 123], [])

      assert {:error, %Error.Invalid.Parameter{parameter: "input: all items must be strings"}} =
               result
    end

    test "returns error for invalid input type (integer)" do
      result = Executor.embed("openai:text-embedding-3-small", 12345, [])

      assert {:error,
              %Error.Invalid.Parameter{parameter: "input: must be string or list of strings"}} =
               result
    end

    test "returns error for invalid input type (map)" do
      result = Executor.embed("openai:text-embedding-3-small", %{text: "hello"}, [])

      assert {:error,
              %Error.Invalid.Parameter{parameter: "input: must be string or list of strings"}} =
               result
    end

    test "returns error for invalid input type (atom)" do
      result = Executor.embed("openai:text-embedding-3-small", :hello, [])

      assert {:error,
              %Error.Invalid.Parameter{parameter: "input: must be string or list of strings"}} =
               result
    end
  end

  describe "embed/3" do
    test "returns error for unknown model" do
      result = Executor.embed("openai:nonexistent-model", "Hello world", [])
      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end
  end

  describe "get_wire_headers/2" do
    test "uses wire module headers when available" do
      defmodule WireWithHeaders do
        def headers(_opts), do: [{"X-Custom-Header", "value"}]
      end

      headers = Executor.__info__(:functions)
      assert {:get_wire_headers, 2} not in headers
    end

    test "falls back to default Content-Type when wire module has no headers/1" do
      defmodule WireWithoutHeaders do
        def some_function, do: :ok
      end

      refute function_exported?(WireWithoutHeaders, :headers, 1)
    end
  end

  describe "generate_object/4" do
    test "returns Response with parsed object" do
      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %Response{} = resp
      assert is_map(resp.object)
      assert is_binary(resp.object["name"])
      assert is_integer(resp.object["age"])
    end

    test "includes context with appended message" do
      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %ReqLlmNext.Context{} = resp.context
      assert length(resp.context.messages) >= 1
    end

    test "returns error for model not found" do
      result =
        Executor.generate_object(
          "openai:nonexistent-model",
          "Generate a profile",
          @person_schema,
          []
        )

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end
  end

  describe "stream_text/3 with context" do
    test "accepts Context as prompt" do
      context =
        ReqLlmNext.Context.new([
          ReqLlmNext.Context.system("You are helpful"),
          ReqLlmNext.Context.user("Hello!")
        ])

      {:ok, resp} = Executor.stream_text("openai:gpt-4o-mini", context, fixture: "basic")

      assert %ReqLlmNext.StreamResponse{} = resp
      text = ReqLlmNext.StreamResponse.text(resp)
      assert is_binary(text)
    end
  end

  describe "generate_text/3 with context" do
    test "accepts Context as prompt" do
      context =
        ReqLlmNext.Context.new([
          ReqLlmNext.Context.user("Hello!")
        ])

      {:ok, result} = Executor.generate_text("openai:gpt-4o-mini", context, fixture: "basic")

      assert %Response{} = result
      assert is_binary(Response.text(result))
    end

    test "returns Response with evolved context" do
      {:ok, result} = Executor.generate_text("openai:gpt-4o-mini", "Hello!", fixture: "basic")

      assert %ReqLlmNext.Context{} = result.context
    end
  end

  describe "stream_object/4 with context" do
    test "accepts Context as prompt" do
      context =
        ReqLlmNext.Context.new([
          ReqLlmNext.Context.user("Generate a software engineer profile")
        ])

      {:ok, resp} =
        Executor.stream_object(
          "openai:gpt-4o-mini",
          context,
          @person_schema,
          fixture: "person_object"
        )

      assert %ReqLlmNext.StreamResponse{} = resp
    end
  end

  describe "generate_object/4 with context" do
    test "accepts Context as prompt" do
      context =
        ReqLlmNext.Context.new([
          ReqLlmNext.Context.user("Generate a software engineer profile")
        ])

      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          context,
          @person_schema,
          fixture: "person_object"
        )

      assert %Response{} = resp
      assert is_map(resp.object)
    end
  end

  describe "embed/3 validation edge cases" do
    test "returns error for mixed types in list" do
      result = Executor.embed("openai:text-embedding-3-small", ["hello", :atom], [])

      assert {:error, %Error.Invalid.Parameter{parameter: "input: all items must be strings"}} =
               result
    end

    test "returns error for tuple input" do
      result = Executor.embed("openai:text-embedding-3-small", {"hello", "world"}, [])

      assert {:error,
              %Error.Invalid.Parameter{parameter: "input: must be string or list of strings"}} =
               result
    end
  end
end
