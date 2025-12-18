defmodule ReqLlmNext.ModelHelpers do
  @moduledoc """
  Helper functions for querying LLMDB.Model capabilities.

  Defines helper functions for common capability checks, centralizing knowledge
  of the model capability structure.

  These helpers ensure consistency when checking model capabilities across the codebase
  and provide a single source of truth for capability access patterns.

  ## Usage

      alias ReqLlmNext.ModelHelpers

      # Check if model supports chat
      ModelHelpers.chat?(model)

      # Check if model supports tool calling
      ModelHelpers.tools_enabled?(model)

      # Check if model supports streaming
      ModelHelpers.streaming_text?(model)
  """

  @capability_checks [
    {:reasoning_enabled?, [:reasoning, :enabled]},
    {:json_native?, [:json, :native]},
    {:json_schema?, [:json, :schema]},
    {:json_strict?, [:json, :strict]},
    {:tools_enabled?, [:tools, :enabled]},
    {:tools_strict?, [:tools, :strict]},
    {:tools_parallel?, [:tools, :parallel]},
    {:tools_streaming?, [:tools, :streaming]},
    {:streaming_text?, [:streaming, :text]},
    {:streaming_tool_calls?, [:streaming, :tool_calls]},
    {:chat?, [:chat]},
    {:embeddings?, [:embeddings]}
  ]

  for {function_name, path} <- @capability_checks do
    path_str = Enum.map_join(path, ".", &to_string/1)

    @doc """
    Check if model has `#{path_str}` capability.

    Returns `true` if `model.capabilities.#{path_str}` is `true`.
    """
    def unquote(function_name)(%LLMDB.Model{} = model) do
      get_in(model.capabilities, unquote(path)) == true
    end

    def unquote(function_name)(_), do: false
  end

  @doc """
  Check if model supports object generation via JSON schema mode.

  Returns true if model has JSON schema support (json.schema == true).
  This is the only reliable indicator from LLMDB that a model supports
  structured output via response_format json_schema.
  """
  @spec supports_object_generation?(LLMDB.Model.t()) :: boolean()
  def supports_object_generation?(%LLMDB.Model{} = model) do
    json_schema?(model)
  end

  def supports_object_generation?(_), do: false

  @doc """
  Check if model supports streaming object generation.

  Requires object generation support AND streaming tool calls not disabled.
  """
  @spec supports_streaming_object_generation?(LLMDB.Model.t()) :: boolean()
  def supports_streaming_object_generation?(%LLMDB.Model{} = model) do
    supports_object_generation?(model) and
      get_in(model.capabilities, [:streaming, :tool_calls]) != false
  end

  def supports_streaming_object_generation?(_), do: false

  @doc """
  Check if model supports image input modality.
  """
  @spec supports_image_input?(LLMDB.Model.t()) :: boolean()
  def supports_image_input?(%LLMDB.Model{} = model) do
    chat?(model) and :image in (model.modalities[:input] || [])
  end

  def supports_image_input?(_), do: false

  @doc """
  Check if model supports audio input modality.
  """
  @spec supports_audio_input?(LLMDB.Model.t()) :: boolean()
  def supports_audio_input?(%LLMDB.Model{} = model) do
    chat?(model) and :audio in (model.modalities[:input] || [])
  end

  def supports_audio_input?(_), do: false

  @doc """
  Check if model supports PDF input modality.
  """
  @spec supports_pdf_input?(LLMDB.Model.t()) :: boolean()
  def supports_pdf_input?(%LLMDB.Model{} = model) do
    chat?(model) and :pdf in (model.modalities[:input] || [])
  end

  def supports_pdf_input?(_), do: false

  @doc """
  List all available capability helper functions.
  """
  @spec list_helpers() :: [atom()]
  def list_helpers do
    @capability_checks
    |> Enum.map(fn {name, _path} -> name end)
    |> Enum.sort()
  end
end
