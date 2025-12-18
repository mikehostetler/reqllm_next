defmodule ReqLlmNext.Adapters.OpenAI.GPT4oMini do
  @moduledoc """
  Adapter for gpt-4o-mini model.

  Demonstrates the adapter pattern by injecting a custom header marker
  that we can verify in tests. In production, this might handle:
  - Default temperature for this model
  - Specific parameter transformations
  - Model-specific constraints
  """

  @behaviour ReqLlmNext.Adapters.ModelAdapter

  @impl true
  def matches?(%LLMDB.Model{id: "gpt-4o-mini", provider: :openai}), do: true
  def matches?(_model), do: false

  @impl true
  def transform_opts(_model, opts) do
    opts
    |> Keyword.put_new(:temperature, 0.7)
    |> Keyword.put(:_adapter_applied, __MODULE__)
  end
end
