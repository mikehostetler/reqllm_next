defmodule ReqLlmNext.Providers do
  @moduledoc """
  Provider registry - maps provider atoms to provider modules.
  """

  @providers %{
    openai: ReqLlmNext.Providers.OpenAI,
    anthropic: ReqLlmNext.Providers.Anthropic
  }

  @spec get(atom()) :: {:ok, module()} | {:error, term()}
  def get(provider_id) when is_atom(provider_id) do
    case Map.get(@providers, provider_id) do
      nil -> {:error, {:unknown_provider, provider_id}}
      module -> {:ok, module}
    end
  end

  @spec get!(atom()) :: module()
  def get!(provider_id) do
    case get(provider_id) do
      {:ok, module} -> module
      {:error, reason} -> raise "Provider error: #{inspect(reason)}"
    end
  end

  @spec list() :: [atom()]
  def list, do: Map.keys(@providers)
end
