defmodule ReqLlmNext.Adapters.Anthropic.Thinking do
  @moduledoc """
  Adapter for Anthropic models with extended thinking.

  Applies transformations when thinking/reasoning is enabled:
  - Sets extended receive_timeout (5 min) for reasoning computation
  - Removes temperature (Anthropic requires default 1.0 for thinking)
  - Constrains top_p to valid range (0.95-1.0)
  - Removes unsupported top_k parameter

  ## Matching

  Applies to Anthropic models when `:thinking` or `:reasoning_effort` is set.

  ## Usage

      # Via reasoning_effort
      opts = [reasoning_effort: :medium]
      ReqLlmNext.generate_text("anthropic:claude-sonnet-4-20250514", "...", opts)

      # Via direct thinking config
      opts = [thinking: %{type: "enabled", budget_tokens: 4096}]
      ReqLlmNext.generate_text("anthropic:claude-sonnet-4-20250514", "...", opts)
  """

  @behaviour ReqLlmNext.Adapters.ModelAdapter

  @default_receive_timeout 300_000

  @impl true
  def matches?(%LLMDB.Model{provider: :anthropic}), do: true
  def matches?(_), do: false

  @impl true
  def transform_opts(_model, opts) do
    if thinking_enabled?(opts) do
      opts
      |> Keyword.put_new(:receive_timeout, @default_receive_timeout)
      |> remove_temperature()
      |> adjust_top_p()
      |> remove_top_k()
      |> adjust_max_tokens_for_thinking()
      |> Keyword.put(:_adapter_applied, __MODULE__)
    else
      opts
    end
  end

  defp thinking_enabled?(opts) do
    Keyword.has_key?(opts, :thinking) or Keyword.has_key?(opts, :reasoning_effort)
  end

  defp remove_temperature(opts) do
    Keyword.delete(opts, :temperature)
  end

  defp adjust_top_p(opts) do
    case Keyword.get(opts, :top_p) do
      nil ->
        opts

      top_p when top_p < 0.95 ->
        Keyword.put(opts, :top_p, 0.95)

      top_p when top_p > 1.0 ->
        Keyword.put(opts, :top_p, 1.0)

      _ ->
        opts
    end
  end

  defp remove_top_k(opts) do
    Keyword.delete(opts, :top_k)
  end

  defp adjust_max_tokens_for_thinking(opts) do
    thinking = Keyword.get(opts, :thinking)
    reasoning_effort = Keyword.get(opts, :reasoning_effort)
    max_tokens = Keyword.get(opts, :max_tokens)

    budget_tokens =
      cond do
        is_map(thinking) -> Map.get(thinking, :budget_tokens, 0)
        not is_nil(reasoning_effort) -> get_budget_for_effort(reasoning_effort)
        true -> 0
      end

    if budget_tokens > 0 and not is_nil(max_tokens) and max_tokens <= budget_tokens do
      Keyword.put(opts, :max_tokens, budget_tokens + 201)
    else
      opts
    end
  end

  defp get_budget_for_effort(:low), do: 1024
  defp get_budget_for_effort(:medium), do: 2048
  defp get_budget_for_effort(:high), do: 4096
  defp get_budget_for_effort("low"), do: 1024
  defp get_budget_for_effort("medium"), do: 2048
  defp get_budget_for_effort("high"), do: 4096
  defp get_budget_for_effort(_), do: 2048
end
