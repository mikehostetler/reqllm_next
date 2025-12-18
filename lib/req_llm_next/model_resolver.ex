defmodule ReqLlmNext.ModelResolver do
  @moduledoc """
  Resolves model specs to LLMDB.Model structs.

  Delegates to LLMDB.model/1 which handles all spec formats:
  - "provider:model_id" strings (e.g., "openai:gpt-4o")
  - {provider, model_id} tuples
  - LLMDB.Model structs (passthrough)
  """

  @spec resolve(String.t() | {atom(), String.t()} | LLMDB.Model.t()) ::
          {:ok, LLMDB.Model.t()} | {:error, term()}
  def resolve(%LLMDB.Model{} = model), do: {:ok, model}

  def resolve(model_spec) do
    case LLMDB.model(model_spec) do
      {:ok, model} -> {:ok, model}
      {:error, reason} -> {:error, {:model_not_found, model_spec, reason}}
    end
  end
end
