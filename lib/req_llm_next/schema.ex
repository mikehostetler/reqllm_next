defmodule ReqLlmNext.Schema do
  @moduledoc """
  Schema compilation and JSON Schema conversion for structured outputs.

  Minimal implementation for v2 tracer bullet - converts NimbleOptions keyword
  schemas to JSON Schema format for use with OpenAI's structured outputs.
  """

  @doc """
  Compiles a keyword schema to a compiled schema wrapper.

  Returns a map with :schema and :compiled fields.
  """
  @spec compile(keyword() | map()) ::
          {:ok, %{schema: keyword() | map(), compiled: term()}} | {:error, term()}
  def compile(schema) when is_map(schema) and not is_struct(schema) do
    {:ok, %{schema: schema, compiled: nil}}
  end

  def compile(schema) when is_list(schema) do
    compiled = NimbleOptions.new!(schema)
    {:ok, %{schema: schema, compiled: compiled}}
  rescue
    e ->
      {:error, {:invalid_schema, Exception.message(e)}}
  end

  def compile(schema) do
    {:error, {:invalid_schema, "Schema must be a keyword list or map, got: #{inspect(schema)}"}}
  end

  @doc """
  Converts a keyword schema to JSON Schema format.

  Note: OpenAI's strict JSON schema mode requires ALL properties to be in the
  `required` array, so we include all properties regardless of the `:required` option.
  """
  @spec to_json(keyword() | map()) :: map()
  def to_json(schema) when is_map(schema) and not is_struct(schema), do: schema

  def to_json([]), do: %{"type" => "object", "properties" => %{}, "required" => []}

  def to_json(schema) when is_list(schema) do
    {properties, all_keys} =
      Enum.reduce(schema, {%{}, []}, fn {key, opts}, {props_acc, keys_acc} ->
        property_name = to_string(key)
        json_prop = nimble_type_to_json_schema(opts[:type] || :string, opts)

        new_props = Map.put(props_acc, property_name, json_prop)
        {new_props, [property_name | keys_acc]}
      end)

    %{
      "type" => "object",
      "properties" => properties,
      "required" => Enum.reverse(all_keys),
      "additionalProperties" => false
    }
  end

  defp nimble_type_to_json_schema(type, opts) do
    base_schema =
      case type do
        :string ->
          %{"type" => "string"}

        :integer ->
          %{"type" => "integer"}

        :pos_integer ->
          %{"type" => "integer", "minimum" => 1}

        :float ->
          %{"type" => "number"}

        :number ->
          %{"type" => "number"}

        :boolean ->
          %{"type" => "boolean"}

        {:list, :string} ->
          %{"type" => "array", "items" => %{"type" => "string"}}

        {:list, :integer} ->
          %{"type" => "array", "items" => %{"type" => "integer"}}

        {:list, item_type} ->
          %{"type" => "array", "items" => nimble_type_to_json_schema(item_type, [])}

        :map ->
          %{"type" => "object"}

        _ ->
          %{"type" => "string"}
      end

    case opts[:doc] do
      nil -> base_schema
      doc -> Map.put(base_schema, "description", doc)
    end
  end

  @doc """
  Validate an object against a compiled schema.

  Returns {:ok, object} if valid, {:error, errors} if invalid.
  For keyword list schemas, validates required fields and field types.
  For map schemas (raw JSON Schema), performs basic validation.
  """
  @spec validate(map(), %{schema: keyword() | map(), compiled: term()}) ::
          {:ok, map()} | {:error, term()}
  def validate(object, %{schema: schema}) when is_map(object) and is_list(schema) do
    errors =
      schema
      |> Enum.reduce([], fn {key, opts}, acc ->
        string_key = to_string(key)
        {value, has_key?} = get_value_with_presence(object, string_key, key)
        required? = Keyword.get(opts, :required, false)
        expected_type = Keyword.get(opts, :type, :string)

        cond do
          required? and not has_key? ->
            [{string_key, "is required"} | acc]

          has_key? and not type_matches?(value, expected_type) ->
            [
              {string_key,
               "expected #{format_type(expected_type)}, got #{format_type(typeof(value))}"}
              | acc
            ]

          true ->
            acc
        end
      end)
      |> Enum.reverse()

    case errors do
      [] -> {:ok, object}
      errors -> {:error, {:validation_errors, errors}}
    end
  end

  def validate(object, %{schema: _schema}) when is_map(object) do
    {:ok, object}
  end

  def validate(_object, _schema) do
    {:error, {:invalid_object, "Object must be a map"}}
  end

  defp get_value_with_presence(object, string_key, atom_key) do
    cond do
      Map.has_key?(object, string_key) -> {Map.get(object, string_key), true}
      Map.has_key?(object, atom_key) -> {Map.get(object, atom_key), true}
      true -> {nil, false}
    end
  end

  defp format_type({:list, inner}), do: "list(#{format_type(inner)})"
  defp format_type(type), do: to_string(type)

  defp type_matches?(value, :string), do: is_binary(value)
  defp type_matches?(value, :integer), do: is_integer(value)
  defp type_matches?(value, :pos_integer), do: is_integer(value) and value > 0
  defp type_matches?(value, :float), do: is_float(value) or is_integer(value)
  defp type_matches?(value, :number), do: is_number(value)
  defp type_matches?(value, :boolean), do: is_boolean(value)
  defp type_matches?(value, :map), do: is_map(value)
  defp type_matches?(value, {:list, _}), do: is_list(value)
  defp type_matches?(_value, _type), do: true

  defp typeof(value) when is_binary(value), do: :string
  defp typeof(value) when is_integer(value), do: :integer
  defp typeof(value) when is_float(value), do: :float
  defp typeof(value) when is_boolean(value), do: :boolean
  defp typeof(value) when is_list(value), do: :list
  defp typeof(value) when is_map(value), do: :map
  defp typeof(_value), do: :unknown

  @doc """
  Convert NimbleOptions schema to JSON Schema format.

  This is an alias for `to_json/1` for API consistency with v1.

  ## Options

    * `:name` - Schema name (optional, adds to JSON Schema)
    * `:description` - Schema description (optional)

  ## Examples

      schema = [
        name: [type: :string, required: true, doc: "User's name"],
        age: [type: :integer, required: true]
      ]
      json_schema = ReqLlmNext.Schema.from_nimble(schema, name: "User")

  """
  @spec from_nimble(keyword(), keyword()) :: map()
  def from_nimble(nimble_schema, opts \\ []) do
    base = to_json(nimble_schema)

    base
    |> maybe_add_name(opts[:name])
    |> maybe_add_description(opts[:description])
  end

  defp maybe_add_name(schema, nil), do: schema
  defp maybe_add_name(schema, name) when is_binary(name), do: Map.put(schema, "title", name)

  defp maybe_add_name(schema, name) when is_atom(name),
    do: Map.put(schema, "title", to_string(name))

  defp maybe_add_description(schema, nil), do: schema
  defp maybe_add_description(schema, desc), do: Map.put(schema, "description", desc)
end
