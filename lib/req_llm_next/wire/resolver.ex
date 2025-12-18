defmodule ReqLlmNext.Wire.Resolver do
  @moduledoc """
  Resolves provider and wire modules for a given model.

  Uses model metadata (provider, extra.wire.protocol) to determine:
  - Which Provider module handles HTTP config (base URL, auth)
  - Which Wire module handles encoding/decoding
  """

  alias ReqLlmNext.{Error, Providers, Wire}

  @type resolution :: %{
          provider_mod: module(),
          wire_mod: module()
        }

  @type operation :: :text | :object | :embed

  @spec resolve!(LLMDB.Model.t()) :: resolution()
  def resolve!(%LLMDB.Model{} = model) do
    %{
      provider_mod: provider_module!(model),
      wire_mod: wire_module!(model)
    }
  end

  @doc """
  Checks if a model uses the OpenAI Responses API.

  Returns true for o-series (o1, o3, o4), GPT-5, and models with `api: "responses"` in extra.
  """
  @spec responses_api?(LLMDB.Model.t()) :: boolean()
  def responses_api?(%LLMDB.Model{} = model) do
    api = get_in(model, [Access.key(:extra, %{}), :api])
    api == "responses" or infer_responses_api?(model.id)
  end

  defp infer_responses_api?(model_id) when is_binary(model_id) do
    cond do
      String.starts_with?(model_id, "o1") -> true
      String.starts_with?(model_id, "o3") -> true
      String.starts_with?(model_id, "o4") -> true
      String.starts_with?(model_id, "gpt-5") -> true
      true -> false
    end
  end

  defp infer_responses_api?(_), do: false

  @spec resolve!(LLMDB.Model.t(), operation()) :: resolution()
  def resolve!(%LLMDB.Model{} = model, :embed) do
    case model.provider do
      :openai ->
        %{provider_mod: Providers.OpenAI, wire_mod: Wire.OpenAIEmbeddings}

      other ->
        raise Error.Invalid.Capability.exception(
                message: "Provider #{other} does not support embeddings"
              )
    end
  end

  def resolve!(%LLMDB.Model{} = model, _operation) do
    resolve!(model)
  end

  @spec provider_module!(LLMDB.Model.t()) :: module()
  def provider_module!(%LLMDB.Model{provider: provider}) do
    Providers.get!(provider)
  end

  @spec wire_module!(LLMDB.Model.t()) :: module()
  def wire_module!(%LLMDB.Model{} = model) do
    protocol = get_wire_protocol(model)

    case protocol do
      :openai_chat -> Wire.OpenAIChat
      :openai_responses -> Wire.OpenAIResponses
      :anthropic -> Wire.Anthropic
      nil -> infer_wire_module(model)
      other -> raise "Unknown wire protocol: #{inspect(other)}"
    end
  end

  @deprecated "Use wire_module!/1 instead"
  def streaming_module!(model), do: wire_module!(model)

  defp get_wire_protocol(%LLMDB.Model{} = model) do
    case get_in(model, [Access.key(:extra, %{}), :wire, :protocol]) do
      nil -> nil
      protocol when is_binary(protocol) -> String.to_existing_atom(protocol)
      protocol when is_atom(protocol) -> protocol
    end
  end

  defp infer_wire_module(%LLMDB.Model{provider: :openai} = model) do
    if responses_api?(model), do: Wire.OpenAIResponses, else: Wire.OpenAIChat
  end

  defp infer_wire_module(%LLMDB.Model{provider: :groq}), do: Wire.OpenAIChat
  defp infer_wire_module(%LLMDB.Model{provider: :openrouter}), do: Wire.OpenAIChat
  defp infer_wire_module(%LLMDB.Model{provider: :xai}), do: Wire.OpenAIChat
  defp infer_wire_module(%LLMDB.Model{provider: :anthropic}), do: Wire.Anthropic
  defp infer_wire_module(_model), do: Wire.OpenAIChat
end
