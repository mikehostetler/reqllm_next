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

  Determines this from LLMDB metadata only (extra.wire.protocol or extra.api).
  """
  @spec responses_api?(LLMDB.Model.t()) :: boolean()
  def responses_api?(%LLMDB.Model{} = model) do
    wire_protocol = get_wire_protocol(model)
    api = get_in(model, [Access.key(:extra, %{}), :api])
    wire_protocol == :openai_responses or api == "responses"
  end

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
    protocol = get_wire_protocol(model) || default_wire_for_provider(model.provider)

    case protocol do
      :openai_chat -> Wire.OpenAIChat
      :openai_responses -> Wire.OpenAIResponses
      :anthropic -> Wire.Anthropic
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

  defp default_wire_for_provider(:openai), do: :openai_chat
  defp default_wire_for_provider(:anthropic), do: :anthropic
  defp default_wire_for_provider(:groq), do: :openai_chat
  defp default_wire_for_provider(:openrouter), do: :openai_chat
  defp default_wire_for_provider(:xai), do: :openai_chat
  defp default_wire_for_provider(_), do: :openai_chat
end
