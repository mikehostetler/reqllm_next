defmodule ReqLlmNext.Tool do
  @moduledoc """
  Tool definition for AI model function calling.

  Tools enable AI models to call external functions, perform actions, and retrieve information.
  Each tool has a name, description, parameters schema, and a callback function to execute.

  ## Basic Usage

      # Create a simple tool
      {:ok, tool} = ReqLlmNext.Tool.new(
        name: "get_weather",
        description: "Get current weather for a location",
        parameter_schema: [
          location: [type: :string, required: true, doc: "City name"]
        ],
        callback: {WeatherService, :get_current_weather}
      )

      # Execute the tool
      {:ok, result} = ReqLlmNext.Tool.execute(tool, %{location: "San Francisco"})

  ## Parameters Schema

  Parameters are defined using NimbleOptions-compatible keyword lists:

      parameter_schema: [
        location: [type: :string, required: true, doc: "City name"],
        units: [type: :string, default: "celsius", doc: "Temperature units"]
      ]

  ## Callback Formats

  Multiple callback formats are supported:

      # Module and function (args passed as single argument)
      callback: {MyModule, :my_function}

      # Module, function, and additional args (prepended to input)
      callback: {MyModule, :my_function, [:extra, :args]}

      # Anonymous function
      callback: fn args -> {:ok, "result"} end

  """

  @type callback_mfa :: {module(), atom()} | {module(), atom(), list()}
  @type callback_fun :: (map() -> {:ok, term()} | {:error, term()})
  @type callback :: callback_mfa() | callback_fun()

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string(),
              description: Zoi.string(),
              parameter_schema: Zoi.any() |> Zoi.default([]),
              compiled: Zoi.any() |> Zoi.nullish(),
              callback: Zoi.any(),
              strict: Zoi.boolean() |> Zoi.default(false)
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          parameter_schema: keyword() | map(),
          compiled: term() | nil,
          callback: callback(),
          strict: boolean()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Tool"
  def schema, do: @schema

  @type tool_opts :: [
          name: String.t(),
          description: String.t(),
          parameter_schema: keyword() | map(),
          callback: callback(),
          strict: boolean()
        ]

  @tool_schema NimbleOptions.new!(
                 name: [
                   type: :string,
                   required: true,
                   doc: "Tool name (must be valid identifier)"
                 ],
                 description: [
                   type: :string,
                   required: true,
                   doc: "Tool description for AI model"
                 ],
                 parameter_schema: [
                   type: :any,
                   default: [],
                   doc: "Parameter schema as keyword list (NimbleOptions) or map (JSON Schema)"
                 ],
                 callback: [
                   type: :any,
                   required: true,
                   doc: "Callback function or MFA tuple"
                 ],
                 strict: [
                   type: :boolean,
                   default: false,
                   doc: "Enable strict mode for OpenAI structured outputs"
                 ]
               )

  @doc """
  Creates a new Tool from the given options.

  ## Parameters

    * `opts` - Tool options as keyword list

  ## Options

    * `:name` - Tool name (required, must be valid identifier)
    * `:description` - Tool description for AI model (required)
    * `:parameter_schema` - Parameter schema as NimbleOptions keyword list or JSON Schema map (optional)
    * `:callback` - Callback function or MFA tuple (required)

  ## Examples

      {:ok, tool} = ReqLlmNext.Tool.new(
        name: "get_weather",
        description: "Get current weather",
        parameter_schema: [
          location: [type: :string, required: true]
        ],
        callback: {WeatherService, :get_weather}
      )

  """
  @spec new(tool_opts()) :: {:ok, t()} | {:error, term()}
  def new(opts) when is_list(opts) do
    with {:ok, validated_opts} <- NimbleOptions.validate(opts, @tool_schema),
         :ok <- validate_name(validated_opts[:name]),
         :ok <- validate_parameter_schema(validated_opts[:parameter_schema]),
         :ok <- validate_callback(validated_opts[:callback]),
         {:ok, compiled_schema} <- compile_parameter_schema(validated_opts[:parameter_schema]) do
      tool = %__MODULE__{
        name: validated_opts[:name],
        description: validated_opts[:description],
        parameter_schema: validated_opts[:parameter_schema],
        compiled: compiled_schema,
        callback: validated_opts[:callback],
        strict: validated_opts[:strict] || false
      }

      {:ok, tool}
    end
  end

  def new(_) do
    {:error, {:invalid_options, "Tool options must be a keyword list"}}
  end

  @doc """
  Creates a new Tool from the given options, raising on error.
  """
  @spec new!(tool_opts()) :: t() | no_return()
  def new!(opts) do
    case new(opts) do
      {:ok, tool} -> tool
      {:error, error} -> raise ArgumentError, "Failed to create tool: #{inspect(error)}"
    end
  end

  @doc """
  Executes a tool with the given input parameters.

  Validates input parameters against the tool's schema and calls the callback function.
  """
  @spec execute(t(), map()) :: {:ok, term()} | {:error, term()}
  def execute(%__MODULE__{} = tool, input) when is_map(input) do
    with {:ok, validated_input} <- validate_input(tool, input) do
      call_callback(tool.callback, validated_input)
    end
  end

  def execute(%__MODULE__{}, input) do
    {:error, {:invalid_input, "Input must be a map, got: #{inspect(input)}"}}
  end

  @doc """
  Converts a Tool to JSON Schema format for LLM integration.
  """
  @spec to_json_schema(t()) :: map()
  def to_json_schema(%__MODULE__{} = tool) do
    to_schema(tool, :openai)
  end

  @doc """
  Converts a Tool to provider-specific schema format.
  """
  @spec to_schema(t(), atom()) :: map()
  def to_schema(%__MODULE__{} = tool, provider \\ :openai) do
    json_schema = schema_to_json(tool.parameter_schema)

    case provider do
      :anthropic ->
        base = %{
          "name" => tool.name,
          "description" => tool.description,
          "input_schema" => json_schema
        }

        if tool.strict, do: Map.put(base, "strict", true), else: base

      :openai ->
        function_def = %{
          "name" => tool.name,
          "description" => tool.description,
          "parameters" => json_schema
        }

        function_def =
          if tool.strict, do: Map.put(function_def, "strict", true), else: function_def

        %{"type" => "function", "function" => function_def}

      :google ->
        %{
          "name" => tool.name,
          "description" => tool.description,
          "parameters" => Map.delete(json_schema, "additionalProperties")
        }

      other ->
        raise ArgumentError, "Unknown provider #{inspect(other)}"
    end
  end

  @doc """
  Validates a tool name for compliance with function calling standards.
  """
  @spec valid_name?(String.t()) :: boolean()
  def valid_name?(name) when is_binary(name) do
    Regex.match?(~r/^[a-zA-Z_][a-zA-Z0-9_]*$/, name) and String.length(name) <= 64
  end

  def valid_name?(_), do: false

  defp validate_name(name) do
    if valid_name?(name) do
      :ok
    else
      {:error,
       {:invalid_name,
        "Invalid tool name: #{inspect(name)}. Must be valid identifier (alphanumeric + underscore, max 64 chars)"}}
    end
  end

  defp validate_parameter_schema(schema) when is_list(schema) or is_map(schema), do: :ok

  defp validate_parameter_schema(schema) do
    {:error,
     {:invalid_schema,
      "Invalid parameter_schema: #{inspect(schema)}. Must be a keyword list or map"}}
  end

  defp validate_callback({module, function}) when is_atom(module) and is_atom(function) do
    if function_exported?(module, function, 1) do
      :ok
    else
      {:error, {:callback_not_found, "Callback function #{module}.#{function}/1 does not exist"}}
    end
  end

  defp validate_callback({module, function, args})
       when is_atom(module) and is_atom(function) and is_list(args) do
    arity = length(args) + 1

    if function_exported?(module, function, arity) do
      :ok
    else
      {:error,
       {:callback_not_found, "Callback function #{module}.#{function}/#{arity} does not exist"}}
    end
  end

  defp validate_callback(fun) when is_function(fun, 1), do: :ok

  defp validate_callback(callback) do
    {:error,
     {:invalid_callback,
      "Invalid callback: #{inspect(callback)}. Must be {module, function}, {module, function, args}, or function/1"}}
  end

  defp compile_parameter_schema([]), do: {:ok, nil}

  defp compile_parameter_schema(schema) when is_list(schema) do
    {:ok, NimbleOptions.new!(schema)}
  rescue
    e -> {:error, {:invalid_schema, Exception.message(e)}}
  end

  defp compile_parameter_schema(_schema), do: {:ok, nil}

  defp validate_input(%__MODULE__{compiled: nil}, input), do: {:ok, input}

  defp validate_input(%__MODULE__{compiled: schema}, input) do
    normalized_input = normalize_input_keys(input)

    case NimbleOptions.validate(normalized_input, schema) do
      {:ok, validated_input} -> {:ok, validated_input}
      {:error, error} -> {:error, {:validation_failed, Exception.message(error)}}
    end
  end

  defp normalize_input_keys(input) when is_map(input) do
    Map.new(input, fn
      {key, value} when is_binary(key) ->
        try do
          {String.to_existing_atom(key), value}
        rescue
          ArgumentError -> {String.to_atom(key), value}
        end

      {key, value} ->
        {key, value}
    end)
  end

  defp call_callback({module, function}, input) do
    apply(module, function, [input])
  rescue
    error -> {:error, {:callback_failed, Exception.message(error)}}
  end

  defp call_callback({module, function, args}, input) do
    apply(module, function, args ++ [input])
  rescue
    error -> {:error, {:callback_failed, Exception.message(error)}}
  end

  defp call_callback(fun, input) when is_function(fun, 1) do
    fun.(input)
  rescue
    error -> {:error, {:callback_failed, Exception.message(error)}}
  end

  defp schema_to_json(schema) when is_map(schema), do: schema

  defp schema_to_json([]), do: %{"type" => "object", "properties" => %{}}

  defp schema_to_json(schema) when is_list(schema) do
    {properties, required} =
      Enum.reduce(schema, {%{}, []}, fn {key, opts}, {props_acc, req_acc} ->
        property_name = to_string(key)
        json_prop = type_to_json_schema(opts[:type] || :string, opts)

        new_props = Map.put(props_acc, property_name, json_prop)
        new_req = if opts[:required], do: [property_name | req_acc], else: req_acc

        {new_props, new_req}
      end)

    schema_object = %{
      "type" => "object",
      "properties" => properties,
      "additionalProperties" => false
    }

    if required == [] do
      schema_object
    else
      Map.put(schema_object, "required", Enum.reverse(required))
    end
  end

  defp type_to_json_schema(type, opts) do
    base_schema =
      case type do
        :string -> %{"type" => "string"}
        :integer -> %{"type" => "integer"}
        :pos_integer -> %{"type" => "integer", "minimum" => 1}
        :float -> %{"type" => "number"}
        :number -> %{"type" => "number"}
        :boolean -> %{"type" => "boolean"}
        {:list, :string} -> %{"type" => "array", "items" => %{"type" => "string"}}
        {:list, :integer} -> %{"type" => "array", "items" => %{"type" => "integer"}}
        {:list, item_type} -> %{"type" => "array", "items" => type_to_json_schema(item_type, [])}
        :map -> %{"type" => "object"}
        {:in, choices} when is_list(choices) -> %{"type" => "string", "enum" => choices}
        _ -> %{"type" => "string"}
      end

    case opts[:doc] do
      nil -> base_schema
      doc -> Map.put(base_schema, "description", doc)
    end
  end

  defimpl Inspect do
    def inspect(%{name: name, parameter_schema: schema}, opts) do
      param_desc =
        cond do
          is_list(schema) ->
            param_count = length(schema)
            if param_count == 0, do: "no params", else: "#{param_count} params"

          is_map(schema) ->
            prop_count = map_size(Map.get(schema, "properties", %{}))

            if prop_count == 0 do
              "no params (JSON Schema)"
            else
              "#{prop_count} params (JSON Schema)"
            end

          true ->
            "unknown schema format"
        end

      Inspect.Algebra.concat([
        "#Tool<",
        Inspect.Algebra.to_doc(name, opts),
        " ",
        param_desc,
        ">"
      ])
    end
  end
end
