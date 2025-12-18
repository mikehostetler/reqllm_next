defmodule ReqLlmNext.ToolTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Tool

  defmodule TestCallbacks do
    def simple_callback(args), do: {:ok, args}
    def with_extra(extra, args), do: {:ok, %{extra: extra, args: args}}
    def failing_callback(_args), do: {:error, "intentional failure"}
  end

  describe "new/1" do
    test "creates tool with required options" do
      {:ok, tool} =
        Tool.new(
          name: "get_weather",
          description: "Get current weather",
          callback: fn _args -> {:ok, "sunny"} end
        )

      assert tool.name == "get_weather"
      assert tool.description == "Get current weather"
      assert tool.parameter_schema == []
    end

    test "creates tool with parameter schema" do
      {:ok, tool} =
        Tool.new(
          name: "get_weather",
          description: "Get current weather",
          parameter_schema: [
            location: [type: :string, required: true, doc: "City name"],
            units: [type: :string, default: "celsius"]
          ],
          callback: fn _args -> {:ok, "sunny"} end
        )

      assert length(tool.parameter_schema) == 2
      assert tool.compiled != nil
    end

    test "creates tool with MFA callback" do
      {:ok, tool} =
        Tool.new(
          name: "test_tool",
          description: "Test tool",
          callback: {TestCallbacks, :simple_callback}
        )

      assert tool.callback == {TestCallbacks, :simple_callback}
    end

    test "creates tool with MFA callback with extra args" do
      {:ok, tool} =
        Tool.new(
          name: "test_tool",
          description: "Test tool",
          callback: {TestCallbacks, :with_extra, [:extra_value]}
        )

      assert tool.callback == {TestCallbacks, :with_extra, [:extra_value]}
    end

    test "creates tool with strict mode" do
      {:ok, tool} =
        Tool.new(
          name: "test_tool",
          description: "Test tool",
          callback: fn _ -> {:ok, nil} end,
          strict: true
        )

      assert tool.strict == true
    end

    test "rejects invalid tool name" do
      {:error, {:invalid_name, _}} =
        Tool.new(
          name: "123invalid",
          description: "Test",
          callback: fn _ -> {:ok, nil} end
        )
    end

    test "rejects missing required options" do
      {:error, _} = Tool.new(name: "test")
    end
  end

  describe "new!/1" do
    test "returns tool on success" do
      tool =
        Tool.new!(
          name: "test_tool",
          description: "Test",
          callback: fn _ -> {:ok, nil} end
        )

      assert %Tool{} = tool
    end

    test "raises on error" do
      assert_raise ArgumentError, fn ->
        Tool.new!(name: "123invalid", description: "Test", callback: fn _ -> {:ok, nil} end)
      end
    end
  end

  describe "execute/2" do
    test "executes anonymous function callback" do
      {:ok, tool} =
        Tool.new(
          name: "echo",
          description: "Echo input",
          callback: fn args -> {:ok, args} end
        )

      assert {:ok, %{message: "hello"}} = Tool.execute(tool, %{message: "hello"})
    end

    test "executes MFA callback" do
      {:ok, tool} =
        Tool.new(
          name: "test",
          description: "Test",
          callback: {TestCallbacks, :simple_callback}
        )

      assert {:ok, %{value: 42}} = Tool.execute(tool, %{value: 42})
    end

    test "executes MFA callback with extra args" do
      {:ok, tool} =
        Tool.new(
          name: "test",
          description: "Test",
          callback: {TestCallbacks, :with_extra, [:my_extra]}
        )

      assert {:ok, result} = Tool.execute(tool, %{input: "data"})
      assert result.extra == :my_extra
      assert result.args == %{input: "data"}
    end

    test "validates input against schema" do
      {:ok, tool} =
        Tool.new(
          name: "validated",
          description: "Validated tool",
          parameter_schema: [
            name: [type: :string, required: true]
          ],
          callback: fn args -> {:ok, args} end
        )

      assert {:ok, result} = Tool.execute(tool, %{name: "test"})
      assert result[:name] == "test"
      assert {:error, {:validation_failed, _}} = Tool.execute(tool, %{})
    end

    test "normalizes string keys to atoms" do
      {:ok, tool} =
        Tool.new(
          name: "normalized",
          description: "Normalized keys",
          parameter_schema: [
            location: [type: :string, required: true]
          ],
          callback: fn args -> {:ok, args} end
        )

      assert {:ok, result} = Tool.execute(tool, %{"location" => "NYC"})
      assert result[:location] == "NYC"
    end

    test "returns error for non-map input" do
      {:ok, tool} =
        Tool.new(
          name: "test",
          description: "Test",
          callback: fn _ -> {:ok, nil} end
        )

      assert {:error, {:invalid_input, _}} = Tool.execute(tool, "not a map")
    end
  end

  describe "to_schema/2" do
    setup do
      {:ok, tool} =
        Tool.new(
          name: "get_weather",
          description: "Get current weather",
          parameter_schema: [
            location: [type: :string, required: true, doc: "City name"],
            units: [type: :string, doc: "Temperature units"]
          ],
          callback: fn _ -> {:ok, nil} end
        )

      {:ok, tool: tool}
    end

    test "generates OpenAI format", %{tool: tool} do
      schema = Tool.to_schema(tool, :openai)

      assert schema["type"] == "function"
      assert schema["function"]["name"] == "get_weather"
      assert schema["function"]["description"] == "Get current weather"
      assert schema["function"]["parameters"]["type"] == "object"
      assert schema["function"]["parameters"]["properties"]["location"]["type"] == "string"
      assert "location" in schema["function"]["parameters"]["required"]
    end

    test "generates Anthropic format", %{tool: tool} do
      schema = Tool.to_schema(tool, :anthropic)

      assert schema["name"] == "get_weather"
      assert schema["description"] == "Get current weather"
      assert schema["input_schema"]["type"] == "object"
      assert schema["input_schema"]["properties"]["location"]["type"] == "string"
    end

    test "generates Google format", %{tool: tool} do
      schema = Tool.to_schema(tool, :google)

      assert schema["name"] == "get_weather"
      assert schema["description"] == "Get current weather"
      assert schema["parameters"]["type"] == "object"
      refute Map.has_key?(schema["parameters"], "additionalProperties")
    end

    test "includes strict flag when set" do
      {:ok, strict_tool} =
        Tool.new(
          name: "strict_tool",
          description: "Strict tool",
          callback: fn _ -> {:ok, nil} end,
          strict: true
        )

      openai_schema = Tool.to_schema(strict_tool, :openai)
      assert openai_schema["function"]["strict"] == true

      anthropic_schema = Tool.to_schema(strict_tool, :anthropic)
      assert anthropic_schema["strict"] == true
    end
  end

  describe "to_json_schema/1" do
    test "delegates to to_schema with :openai" do
      {:ok, tool} =
        Tool.new(
          name: "test",
          description: "Test",
          callback: fn _ -> {:ok, nil} end
        )

      assert Tool.to_json_schema(tool) == Tool.to_schema(tool, :openai)
    end
  end

  describe "valid_name?/1" do
    test "accepts valid names" do
      assert Tool.valid_name?("get_weather")
      assert Tool.valid_name?("getWeather")
      assert Tool.valid_name?("_private")
      assert Tool.valid_name?("tool123")
    end

    test "rejects invalid names" do
      refute Tool.valid_name?("123invalid")
      refute Tool.valid_name?("has-dash")
      refute Tool.valid_name?("has space")
      refute Tool.valid_name?("")
      refute Tool.valid_name?(String.duplicate("a", 65))
    end

    test "rejects non-strings" do
      refute Tool.valid_name?(:atom)
      refute Tool.valid_name?(123)
    end
  end

  describe "Inspect" do
    test "shows name and param count" do
      {:ok, tool} =
        Tool.new(
          name: "my_tool",
          description: "My tool",
          parameter_schema: [a: [type: :string], b: [type: :integer]],
          callback: fn _ -> {:ok, nil} end
        )

      result = inspect(tool)
      assert result =~ "#Tool<"
      assert result =~ "my_tool"
      assert result =~ "2 params"
    end

    test "shows no params for empty schema" do
      {:ok, tool} =
        Tool.new(
          name: "simple",
          description: "Simple",
          callback: fn _ -> {:ok, nil} end
        )

      result = inspect(tool)
      assert result =~ "no params"
    end

    test "shows JSON Schema format for map schema" do
      {:ok, tool} =
        Tool.new(
          name: "json_tool",
          description: "JSON tool",
          parameter_schema: %{
            "type" => "object",
            "properties" => %{
              "a" => %{"type" => "string"},
              "b" => %{"type" => "integer"}
            }
          },
          callback: fn _ -> {:ok, nil} end
        )

      result = inspect(tool)
      assert result =~ "2 params (JSON Schema)"
    end

    test "shows no params for empty JSON Schema properties" do
      {:ok, tool} =
        Tool.new(
          name: "empty_json",
          description: "Empty JSON",
          parameter_schema: %{"type" => "object", "properties" => %{}},
          callback: fn _ -> {:ok, nil} end
        )

      result = inspect(tool)
      assert result =~ "no params (JSON Schema)"
    end
  end

  describe "new/1 edge cases" do
    test "rejects non-keyword list options" do
      {:error, {:invalid_options, _}} = Tool.new(%{name: "test"})
    end

    test "rejects callback that doesn't exist" do
      {:error, {:callback_not_found, msg}} =
        Tool.new(
          name: "test",
          description: "Test",
          callback: {NonExistentModule, :non_existent_function}
        )

      assert msg =~ "does not exist"
    end

    test "rejects invalid callback format" do
      {:error, {:invalid_callback, _}} =
        Tool.new(
          name: "test",
          description: "Test",
          callback: "not_a_callback"
        )
    end

    test "rejects invalid parameter schema type" do
      {:error, {:invalid_schema, _}} =
        Tool.new(
          name: "test",
          description: "Test",
          parameter_schema: "invalid",
          callback: fn _ -> {:ok, nil} end
        )
    end

    test "rejects malformed NimbleOptions schema" do
      {:error, {:invalid_schema, _}} =
        Tool.new(
          name: "test",
          description: "Test",
          parameter_schema: [invalid_key: [invalid_option: true]],
          callback: fn _ -> {:ok, nil} end
        )
    end

    test "accepts tool name at max length" do
      name = String.duplicate("a", 64)

      {:ok, tool} =
        Tool.new(
          name: name,
          description: "Test",
          callback: fn _ -> {:ok, nil} end
        )

      assert tool.name == name
    end
  end

  describe "execute/2 edge cases" do
    test "handles callback that returns error tuple" do
      {:ok, tool} =
        Tool.new(
          name: "failing",
          description: "Fails",
          callback: {TestCallbacks, :failing_callback}
        )

      assert {:error, "intentional failure"} = Tool.execute(tool, %{})
    end

    test "handles callback that raises" do
      {:ok, tool} =
        Tool.new(
          name: "raising",
          description: "Raises",
          callback: fn _ -> raise "boom" end
        )

      assert {:error, {:callback_failed, msg}} = Tool.execute(tool, %{})
      assert msg =~ "boom"
    end

    test "executes with empty map input" do
      {:ok, tool} =
        Tool.new(
          name: "empty",
          description: "Empty",
          callback: fn args -> {:ok, map_size(args)} end
        )

      assert {:ok, 0} = Tool.execute(tool, %{})
    end
  end

  describe "to_schema/2 type conversions" do
    test "converts various NimbleOptions types" do
      {:ok, tool} =
        Tool.new(
          name: "types_tool",
          description: "Tests types",
          parameter_schema: [
            string_field: [type: :string, doc: "A string"],
            integer_field: [type: :integer],
            pos_int_field: [type: :pos_integer],
            float_field: [type: :float],
            boolean_field: [type: :boolean],
            list_strings: [type: {:list, :string}],
            list_ints: [type: {:list, :integer}],
            list_nested: [type: {:list, :boolean}],
            map_field: [type: :map],
            enum_field: [type: {:in, ["a", "b", "c"]}]
          ],
          callback: fn _ -> {:ok, nil} end
        )

      schema = Tool.to_schema(tool, :openai)
      props = schema["function"]["parameters"]["properties"]

      assert props["string_field"] == %{"type" => "string", "description" => "A string"}
      assert props["integer_field"] == %{"type" => "integer"}
      assert props["pos_int_field"] == %{"type" => "integer", "minimum" => 1}
      assert props["float_field"] == %{"type" => "number"}
      assert props["boolean_field"] == %{"type" => "boolean"}
      assert props["list_strings"] == %{"type" => "array", "items" => %{"type" => "string"}}
      assert props["list_ints"] == %{"type" => "array", "items" => %{"type" => "integer"}}
      assert props["list_nested"] == %{"type" => "array", "items" => %{"type" => "boolean"}}
      assert props["map_field"] == %{"type" => "object"}
      assert props["enum_field"] == %{"type" => "string", "enum" => ["a", "b", "c"]}
    end

    test "raises for unknown provider" do
      {:ok, tool} =
        Tool.new(
          name: "test",
          description: "Test",
          callback: fn _ -> {:ok, nil} end
        )

      assert_raise ArgumentError, ~r/Unknown provider/, fn ->
        Tool.to_schema(tool, :unknown_provider)
      end
    end

    test "handles empty parameter schema" do
      {:ok, tool} =
        Tool.new(
          name: "no_params",
          description: "No params",
          callback: fn _ -> {:ok, nil} end
        )

      schema = Tool.to_schema(tool, :openai)
      assert schema["function"]["parameters"] == %{"type" => "object", "properties" => %{}}
    end

    test "passes through JSON Schema map directly" do
      json_schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        },
        "required" => ["name"]
      }

      {:ok, tool} =
        Tool.new(
          name: "json_schema_tool",
          description: "Uses JSON Schema",
          parameter_schema: json_schema,
          callback: fn _ -> {:ok, nil} end
        )

      schema = Tool.to_schema(tool, :openai)
      assert schema["function"]["parameters"] == json_schema
    end

    test "omits additionalProperties for Google format" do
      {:ok, tool} =
        Tool.new(
          name: "google_tool",
          description: "For Google",
          parameter_schema: [field: [type: :string, required: true]],
          callback: fn _ -> {:ok, nil} end
        )

      schema = Tool.to_schema(tool, :google)
      refute Map.has_key?(schema["parameters"], "additionalProperties")
      assert schema["parameters"]["type"] == "object"
    end
  end

  describe "schema/0" do
    test "returns Zoi schema" do
      schema = Tool.schema()
      assert is_struct(schema)
    end
  end

  describe "Inspect edge cases" do
    test "handles unknown schema format" do
      tool = %Tool{
        name: "weird_schema",
        description: "Weird",
        parameter_schema: :not_list_or_map,
        compiled: nil,
        callback: fn _ -> {:ok, nil} end,
        strict: false
      }

      result = inspect(tool)
      assert result =~ "#Tool<"
      assert result =~ "weird_schema"
      assert result =~ "unknown schema format"
    end

    test "handles JSON Schema with no properties key" do
      {:ok, tool} =
        Tool.new(
          name: "no_props",
          description: "No properties",
          parameter_schema: %{"type" => "object"},
          callback: fn _ -> {:ok, nil} end
        )

      result = inspect(tool)
      assert result =~ "#Tool<"
      assert result =~ "no_props"
      assert result =~ "no params (JSON Schema)"
    end
  end
end
