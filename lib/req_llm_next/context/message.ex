defmodule ReqLlmNext.Context.Message do
  @moduledoc """
  Message represents a single conversation message with multi-modal content support.

  Content is always a list of `ContentPart` structs, never a string.
  This ensures consistent handling across all providers and eliminates polymorphism.

  ## Reasoning Details

  The `reasoning_details` field contains provider-specific reasoning metadata that must
  be preserved across conversation turns for reasoning models. This field is:
  - `nil` for non-reasoning models or models that don't provide structured reasoning metadata
  - A list of maps for reasoning models (format varies by provider)

  ### OpenRouter Format

  OpenRouter returns reasoning details for models like Gemini 3, DeepSeek R1:
  ```elixir
  [
    %{
      "type" => "reasoning.text",
      "format" => "google-gemini-v1",  # or "unknown"
      "index" => 0,
      "text" => "Step-by-step reasoning..."
    }
  ]
  ```

  These details are automatically:
  - Extracted from provider responses
  - Preserved and re-sent in multi-turn conversations

  For multi-turn reasoning continuity, include the previous assistant message
  (with its reasoning_details) in subsequent requests.
  """

  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.ToolCall

  @derive Jason.Encoder
  @schema Zoi.struct(
            __MODULE__,
            %{
              role: Zoi.enum([:user, :assistant, :system, :tool]),
              content: Zoi.array(Zoi.any()) |> Zoi.default([]),
              name: Zoi.string() |> Zoi.nullish(),
              tool_call_id: Zoi.string() |> Zoi.nullish(),
              tool_calls: Zoi.array(Zoi.any()) |> Zoi.nullish(),
              metadata: Zoi.map() |> Zoi.default(%{}),
              reasoning_details: Zoi.array(Zoi.map()) |> Zoi.nullish()
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          role: :user | :assistant | :system | :tool,
          content: [ContentPart.t()],
          name: String.t() | nil,
          tool_call_id: String.t() | nil,
          tool_calls: [ToolCall.t()] | nil,
          metadata: map(),
          reasoning_details: [map()] | nil
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Message"
  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, message} -> message
      {:error, reason} -> raise ArgumentError, "Invalid message: #{inspect(reason)}"
    end
  end

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{content: content}) when is_list(content), do: true
  def valid?(_), do: false

  defimpl Inspect do
    def inspect(%{role: role, content: parts}, opts) do
      summary =
        parts
        |> Enum.map_join(",", & &1.type)

      Inspect.Algebra.concat(["#Message<", Inspect.Algebra.to_doc(role, opts), " ", summary, ">"])
    end
  end
end
