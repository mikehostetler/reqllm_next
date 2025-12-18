defmodule ReqLlmNext.Adapters.OpenAI.Reasoning do
  @moduledoc """
  Adapter for OpenAI reasoning models (o-series, GPT-5).

  Sets appropriate defaults for reasoning models that use the Responses API:
  - Higher default max_completion_tokens (16K) for extended thinking
  - Longer receive_timeout (5 min) for reasoning computation
  - Normalizes max_tokens to max_completion_tokens

  ## Matching Models

  Applies to models with:
  - `extra.api: "responses"` in metadata
  - Model IDs starting with: o1, o3, o4, gpt-5
  """

  @behaviour ReqLlmNext.Adapters.ModelAdapter

  alias ReqLlmNext.Wire.Resolver

  @default_max_completion_tokens 16_000
  @default_receive_timeout 300_000

  @impl true
  def matches?(%LLMDB.Model{} = model) do
    Resolver.responses_api?(model)
  end

  @impl true
  def transform_opts(model, opts) do
    opts
    |> normalize_max_tokens()
    |> Keyword.put_new(:max_completion_tokens, @default_max_completion_tokens)
    |> Keyword.put_new(:receive_timeout, @default_receive_timeout)
    |> Keyword.put(:_adapter_applied, __MODULE__)
    |> maybe_remove_temperature(model)
  end

  defp normalize_max_tokens(opts) do
    max_tokens = Keyword.get(opts, :max_tokens)
    max_output_tokens = Keyword.get(opts, :max_output_tokens)
    max_completion_tokens = Keyword.get(opts, :max_completion_tokens)

    effective_max = max_completion_tokens || max_output_tokens || max_tokens

    if effective_max do
      opts
      |> Keyword.put(:max_completion_tokens, effective_max)
      |> Keyword.delete(:max_tokens)
    else
      opts
    end
  end

  defp maybe_remove_temperature(opts, _model) do
    if Keyword.has_key?(opts, :temperature) do
      Keyword.delete(opts, :temperature)
    else
      opts
    end
  end
end
