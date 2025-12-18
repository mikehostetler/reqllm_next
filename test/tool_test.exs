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
  end
end
