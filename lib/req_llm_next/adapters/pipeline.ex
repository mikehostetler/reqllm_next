defmodule ReqLlmNext.Adapters.Pipeline do
  @moduledoc """
  Resolves and executes adapters for a model.

  Adapters are registered here and matched against models.
  The pipeline runs all matching adapters in order.
  """

  @adapters [
    ReqLlmNext.Adapters.OpenAI.Reasoning,
    ReqLlmNext.Adapters.OpenAI.GPT4oMini,
    ReqLlmNext.Adapters.Anthropic.Thinking
  ]

  @spec adapters_for(LLMDB.Model.t()) :: [module()]
  def adapters_for(model) do
    Enum.filter(@adapters, fn adapter_mod ->
      adapter_mod.matches?(model)
    end)
  end

  @spec apply(LLMDB.Model.t(), keyword()) :: keyword()
  def apply(model, opts) do
    model
    |> adapters_for()
    |> Enum.reduce(opts, fn adapter_mod, acc_opts ->
      adapter_mod.transform_opts(model, acc_opts)
    end)
  end
end
