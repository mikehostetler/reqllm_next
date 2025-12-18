defmodule ReqLlmNext.Validation do
  @moduledoc """
  Validates operations against model capabilities using LLMDB metadata.

  No model-name heuristics - all checks derive from metadata.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Error

  @type operation :: :text | :object | :embed

  @spec validate!(LLMDB.Model.t(), operation(), Context.t() | nil, keyword()) :: :ok | no_return()
  def validate!(model, operation, context, opts) do
    with :ok <- validate_operation(model, operation),
         :ok <- validate_modalities(model, context),
         :ok <- validate_capabilities(model, opts) do
      :ok
    else
      {:error, error} -> raise error
    end
  end

  @spec validate_stream!(LLMDB.Model.t(), String.t() | Context.t(), keyword()) :: :ok
  def validate_stream!(model, prompt, opts) do
    context =
      case prompt do
        %Context{} = ctx -> ctx
        _ -> nil
      end

    validate!(model, :text, context, opts)
  end

  @spec validate_operation(LLMDB.Model.t(), operation()) :: :ok | {:error, term()}
  defp validate_operation(model, operation) do
    kind = model_kind(model)

    case {kind, operation} do
      {:embedding, :text} ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Embedding model #{model.id} cannot generate text"
         )}

      {:embedding, :object} ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Embedding model #{model.id} cannot generate objects"
         )}

      {k, :embed} when k != :embedding ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{model.id} does not support embeddings"
         )}

      _ ->
        :ok
    end
  end

  @spec validate_modalities(LLMDB.Model.t(), Context.t() | nil) :: :ok | {:error, term()}
  defp validate_modalities(_model, nil), do: :ok

  defp validate_modalities(model, context) do
    input_modalities = get_input_modalities(model)
    has_images = context_has_images?(context)

    if has_images and :image not in input_modalities do
      {:error,
       Error.Invalid.Capability.exception(
         message: "Model #{model.id} does not support image inputs",
         missing: [:vision]
       )}
    else
      :ok
    end
  end

  @spec validate_capabilities(LLMDB.Model.t(), keyword()) :: :ok | {:error, term()}
  defp validate_capabilities(model, opts) do
    capabilities = model_capabilities(model)

    cond do
      Keyword.has_key?(opts, :tools) and not capabilities_has?(capabilities, :tools) ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{model.id} does not support tool calling",
           missing: [:tools]
         )}

      Keyword.get(opts, :stream, false) and not capabilities_has?(capabilities, :streaming) ->
        {:error,
         Error.Invalid.Capability.exception(
           message: "Model #{model.id} does not support streaming",
           missing: [:streaming]
         )}

      true ->
        :ok
    end
  end

  defp capabilities_has?(caps, :tools) do
    get_in(caps, [:tools, :enabled]) == true
  end

  defp capabilities_has?(caps, :streaming) do
    get_in(caps, [:streaming, :text]) == true
  end

  defp model_kind(%LLMDB.Model{} = model) do
    extra = Map.get(model, :extra, %{}) || %{}

    cond do
      Map.get(extra, :kind) -> Map.get(extra, :kind)
      Map.get(extra, :type) == "embedding" -> :embedding
      true -> infer_kind(model)
    end
  end

  defp infer_kind(%LLMDB.Model{capabilities: caps}) when is_map(caps) do
    cond do
      has_embeddings?(caps) -> :embedding
      has_reasoning?(caps) -> :reasoning
      true -> :chat
    end
  end

  defp infer_kind(_), do: :chat

  defp has_embeddings?(%{embeddings: %{} = emb}) when map_size(emb) > 0, do: true
  defp has_embeddings?(%{embeddings: true}), do: true
  defp has_embeddings?(_), do: false

  defp has_reasoning?(%{reasoning: %{enabled: true}}), do: true
  defp has_reasoning?(%{reasoning: true}), do: true
  defp has_reasoning?(_), do: false

  defp model_capabilities(%LLMDB.Model{capabilities: nil}), do: default_capabilities()
  defp model_capabilities(%LLMDB.Model{capabilities: caps}), do: caps

  defp default_capabilities do
    %{
      chat: true,
      streaming: %{text: true},
      tools: %{enabled: true},
      embeddings: false
    }
  end

  defp get_input_modalities(%LLMDB.Model{modalities: %{input: input}}) when is_list(input),
    do: input

  defp get_input_modalities(_), do: [:text]

  defp context_has_images?(%Context{messages: messages}) do
    Enum.any?(messages, fn msg ->
      Enum.any?(msg.content || [], fn
        %ContentPart{type: type} -> type in [:image, :image_url]
        _ -> false
      end)
    end)
  end

  defp context_has_images?(_), do: false
end
