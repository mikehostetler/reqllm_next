defmodule ReqLlmNext.Executor.GenerateObjectTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Executor, Response}

  @person_schema [
    name: [type: :string, required: true, doc: "Person's full name"],
    age: [type: :integer, required: true, doc: "Person's age in years"],
    occupation: [type: :string, doc: "Person's job or profession"]
  ]

  describe "generate_object/4" do
    test "returns Response with object field populated" do
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
      assert resp.model.provider == :openai
      assert resp.model.id == "gpt-4o-mini"
    end

    test "validates object against schema" do
      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert resp.object["name"] != nil
      assert resp.object["age"] != nil
    end

    test "includes context with assistant message" do
      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert %ReqLlmNext.Context{} = resp.context
      messages = ReqLlmNext.Context.to_list(resp.context)
      refute Enum.empty?(messages)

      assistant_messages = Enum.filter(messages, &(&1.role == :assistant))
      refute Enum.empty?(assistant_messages)
    end

    test "returns error for unknown model" do
      result =
        Executor.generate_object(
          "openai:nonexistent-model",
          "Generate a profile",
          @person_schema,
          []
        )

      assert {:error, {:model_not_found, "openai:nonexistent-model", _}} = result
    end

    test "works with map schema (raw JSON Schema)" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name", "age"]
      }

      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          json_schema,
          fixture: "person_object"
        )

      assert %Response{} = resp
      assert is_map(resp.object)
    end

    test "sets finish_reason to :stop" do
      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert resp.finish_reason == :stop
    end

    test "stream? is false for non-streaming response" do
      {:ok, resp} =
        Executor.generate_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      assert resp.stream? == false
      assert resp.stream == nil
    end
  end
end
