defmodule ReqLlmNext.SchemaTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Schema

  describe "validate/2" do
    test "validates required fields are present" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      ]

      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, %{"name" => "John", "age" => 30}} =
               Schema.validate(%{"name" => "John", "age" => 30}, compiled)
    end

    test "returns error for missing required fields" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      ]

      {:ok, compiled} = Schema.compile(schema)

      assert {:error, {:validation_errors, errors}} =
               Schema.validate(%{"name" => "John"}, compiled)

      assert {"age", "is required"} in errors
    end

    test "validates field types" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      ]

      {:ok, compiled} = Schema.compile(schema)

      assert {:error, {:validation_errors, errors}} =
               Schema.validate(%{"name" => "John", "age" => "thirty"}, compiled)

      assert Enum.any?(errors, fn {key, msg} ->
               key == "age" and String.contains?(msg, "expected")
             end)
    end

    test "returns error for wrong types" do
      schema = [
        count: [type: :integer, required: true],
        active: [type: :boolean, required: true]
      ]

      {:ok, compiled} = Schema.compile(schema)

      assert {:error, {:validation_errors, errors}} =
               Schema.validate(%{"count" => "five", "active" => "yes"}, compiled)

      assert length(errors) == 2
    end

    test "accepts optional fields when not present" do
      schema = [
        name: [type: :string, required: true],
        nickname: [type: :string, required: false]
      ]

      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, %{"name" => "John"}} = Schema.validate(%{"name" => "John"}, compiled)
    end

    test "validates optional fields when present" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, required: false]
      ]

      {:ok, compiled} = Schema.compile(schema)

      assert {:error, {:validation_errors, errors}} =
               Schema.validate(%{"name" => "John", "age" => "invalid"}, compiled)

      assert {"age", _} = List.first(errors)
    end

    test "validates string type" do
      schema = [value: [type: :string, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => "hello"}, compiled)
      assert {:error, _} = Schema.validate(%{"value" => 123}, compiled)
    end

    test "validates integer type" do
      schema = [value: [type: :integer, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => 42}, compiled)
      assert {:error, _} = Schema.validate(%{"value" => "42"}, compiled)
    end

    test "validates boolean type" do
      schema = [value: [type: :boolean, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => true}, compiled)
      assert {:ok, _} = Schema.validate(%{"value" => false}, compiled)
      assert {:error, _} = Schema.validate(%{"value" => "true"}, compiled)
    end

    test "validates float/number type" do
      schema = [value: [type: :float, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => 3.14}, compiled)
      assert {:ok, _} = Schema.validate(%{"value" => 42}, compiled)
      assert {:error, _} = Schema.validate(%{"value" => "3.14"}, compiled)
    end

    test "validates map type" do
      schema = [value: [type: :map, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => %{"nested" => "data"}}, compiled)
      assert {:error, _} = Schema.validate(%{"value" => "not a map"}, compiled)
    end

    test "validates list type" do
      schema = [value: [type: {:list, :string}, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => ["a", "b", "c"]}, compiled)
      assert {:error, _} = Schema.validate(%{"value" => "not a list"}, compiled)
    end

    test "passes through map schemas without validation" do
      json_schema = %{
        "type" => "object",
        "properties" => %{"name" => %{"type" => "string"}}
      }

      {:ok, compiled} = Schema.compile(json_schema)
      assert {:ok, %{"name" => "John"}} = Schema.validate(%{"name" => "John"}, compiled)
      assert {:ok, %{"invalid" => true}} = Schema.validate(%{"invalid" => true}, compiled)
    end

    test "returns error for non-map objects" do
      schema = [name: [type: :string, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:error, {:invalid_object, _}} = Schema.validate("not a map", compiled)
      assert {:error, {:invalid_object, _}} = Schema.validate(123, compiled)
    end

    test "handles atom keys in object" do
      schema = [name: [type: :string, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{name: "John"}, compiled)
    end
  end
end
