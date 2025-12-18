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

  describe "compile/1" do
    test "compiles keyword list schema" do
      schema = [name: [type: :string, required: true]]
      assert {:ok, %{schema: ^schema, compiled: compiled}} = Schema.compile(schema)
      assert compiled != nil
    end

    test "compiles map schema (raw JSON Schema)" do
      json_schema = %{"type" => "object", "properties" => %{}}
      assert {:ok, %{schema: ^json_schema, compiled: nil}} = Schema.compile(json_schema)
    end

    test "returns error for invalid keyword schema" do
      invalid = [name: [type: :invalid_type_that_does_not_exist_xyz]]
      assert {:error, {:invalid_schema, _}} = Schema.compile(invalid)
    end

    test "returns error for non-list non-map input" do
      assert {:error, {:invalid_schema, msg}} = Schema.compile("not a schema")
      assert msg =~ "must be a keyword list or map"
    end

    test "compiles empty schema" do
      assert {:ok, %{schema: [], compiled: _}} = Schema.compile([])
    end
  end

  describe "to_json/1" do
    test "converts simple string field" do
      schema = [name: [type: :string]]
      json = Schema.to_json(schema)

      assert json["type"] == "object"
      assert json["properties"]["name"]["type"] == "string"
      assert "name" in json["required"]
    end

    test "converts integer field" do
      schema = [count: [type: :integer]]
      json = Schema.to_json(schema)

      assert json["properties"]["count"]["type"] == "integer"
    end

    test "converts pos_integer field with minimum" do
      schema = [page: [type: :pos_integer]]
      json = Schema.to_json(schema)

      assert json["properties"]["page"]["type"] == "integer"
      assert json["properties"]["page"]["minimum"] == 1
    end

    test "converts float field" do
      schema = [price: [type: :float]]
      json = Schema.to_json(schema)

      assert json["properties"]["price"]["type"] == "number"
    end

    test "converts number field" do
      schema = [value: [type: :number]]
      json = Schema.to_json(schema)

      assert json["properties"]["value"]["type"] == "number"
    end

    test "converts boolean field" do
      schema = [active: [type: :boolean]]
      json = Schema.to_json(schema)

      assert json["properties"]["active"]["type"] == "boolean"
    end

    test "converts list of strings" do
      schema = [tags: [type: {:list, :string}]]
      json = Schema.to_json(schema)

      assert json["properties"]["tags"]["type"] == "array"
      assert json["properties"]["tags"]["items"]["type"] == "string"
    end

    test "converts list of integers" do
      schema = [numbers: [type: {:list, :integer}]]
      json = Schema.to_json(schema)

      assert json["properties"]["numbers"]["type"] == "array"
      assert json["properties"]["numbers"]["items"]["type"] == "integer"
    end

    test "converts nested list type" do
      schema = [values: [type: {:list, :boolean}]]
      json = Schema.to_json(schema)

      assert json["properties"]["values"]["type"] == "array"
      assert json["properties"]["values"]["items"]["type"] == "boolean"
    end

    test "converts map field" do
      schema = [metadata: [type: :map]]
      json = Schema.to_json(schema)

      assert json["properties"]["metadata"]["type"] == "object"
    end

    test "includes doc as description" do
      schema = [name: [type: :string, doc: "The user's full name"]]
      json = Schema.to_json(schema)

      assert json["properties"]["name"]["description"] == "The user's full name"
    end

    test "defaults unknown type to string" do
      schema = [value: [type: :unknown_custom_type]]
      json = Schema.to_json(schema)

      assert json["properties"]["value"]["type"] == "string"
    end

    test "sets additionalProperties to false" do
      schema = [name: [type: :string]]
      json = Schema.to_json(schema)

      assert json["additionalProperties"] == false
    end

    test "all fields in required array" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, required: false],
        email: [type: :string]
      ]

      json = Schema.to_json(schema)

      assert json["required"] == ["name", "age", "email"]
    end

    test "passes through raw JSON schema map" do
      raw = %{"type" => "object", "custom" => true}
      assert Schema.to_json(raw) == raw
    end

    test "handles empty schema" do
      json = Schema.to_json([])

      assert json["type"] == "object"
      assert json["properties"] == %{}
      assert json["required"] == []
    end
  end

  describe "from_nimble/2" do
    test "adds title from name option" do
      schema = [name: [type: :string]]
      json = Schema.from_nimble(schema, name: "Person")

      assert json["title"] == "Person"
    end

    test "adds title from atom name" do
      schema = [name: [type: :string]]
      json = Schema.from_nimble(schema, name: :User)

      assert json["title"] == "User"
    end

    test "adds description option" do
      schema = [name: [type: :string]]
      json = Schema.from_nimble(schema, description: "A person object")

      assert json["description"] == "A person object"
    end

    test "adds both name and description" do
      schema = [name: [type: :string]]
      json = Schema.from_nimble(schema, name: "Person", description: "User profile")

      assert json["title"] == "Person"
      assert json["description"] == "User profile"
    end

    test "works without options" do
      schema = [name: [type: :string]]
      json = Schema.from_nimble(schema)

      assert json["type"] == "object"
      refute Map.has_key?(json, "title")
    end
  end

  describe "validate/2 type validation" do
    test "validates pos_integer type" do
      schema = [count: [type: :pos_integer, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"count" => 5}, compiled)
      assert {:error, _} = Schema.validate(%{"count" => 0}, compiled)
      assert {:error, _} = Schema.validate(%{"count" => -1}, compiled)
    end

    test "validates float type accepts integers" do
      schema = [value: [type: :float, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => 42}, compiled)
      assert {:ok, _} = Schema.validate(%{"value" => 3.14}, compiled)
      assert {:error, _} = Schema.validate(%{"value" => "42"}, compiled)
    end

    test "any type passes validation" do
      schema = [value: [type: :any, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:ok, _} = Schema.validate(%{"value" => "anything"}, compiled)
      assert {:ok, _} = Schema.validate(%{"value" => 123}, compiled)
      assert {:ok, _} = Schema.validate(%{"value" => %{nested: true}}, compiled)
    end

    test "formats type error message correctly for list type" do
      schema = [items: [type: {:list, :string}, required: true]]
      {:ok, compiled} = Schema.compile(schema)

      assert {:error, {:validation_errors, [{"items", msg}]}} =
               Schema.validate(%{"items" => "not a list"}, compiled)

      assert msg =~ "list"
    end
  end
end
