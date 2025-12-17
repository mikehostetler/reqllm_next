defmodule ReqLlmNext.ModelResolver do
  @moduledoc """
  Resolves model specs to LLMDB.Model structs.

  Tracer bullet - only supports "openai:gpt-4o-mini" for now.
  """

  @spec resolve(String.t()) :: {:ok, LLMDB.Model.t()} | {:error, term()}
  def resolve("openai:" <> model_id) do
    case LLMDB.model(:openai, model_id) do
      {:ok, model} -> {:ok, model}
      {:error, reason} -> {:error, {:model_not_found, reason}}
    end
  end

  def resolve(model_spec) do
    {:error, {:invalid_model_spec, model_spec}}
  end
end
