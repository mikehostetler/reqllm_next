defmodule ReqLlmNext.Constraints do
  @moduledoc """
  Applies parameter constraints from LLMDB metadata.

  All constraint logic flows from model metadata - no model name heuristics.

  ## Constraint Types

  - `temperature`: :any | :fixed_1 | :unsupported
  - `sampling`: :supported | :unsupported (applies to top_p, top_k)
  - `token_limit_key`: :max_tokens | :max_completion_tokens
  - `reasoning_effort`: :unsupported | :supported | :required
  - `min_output_tokens`: integer minimum for output tokens
  """

  @spec apply(LLMDB.Model.t(), keyword()) :: keyword()
  def apply(model, opts) do
    constraints = get_constraints(model)

    opts
    |> apply_token_limit_key(constraints)
    |> apply_temperature_constraint(constraints)
    |> apply_sampling_constraint(constraints)
    |> apply_min_output_tokens(constraints)
    |> apply_reasoning_effort(constraints)
  end

  defp get_constraints(%LLMDB.Model{} = model) do
    extra = Map.get(model, :extra, %{}) || %{}
    Map.get(extra, :constraints, %{}) || %{}
  end

  defp apply_token_limit_key(opts, %{token_limit_key: :max_completion_tokens}) do
    case Keyword.pop(opts, :max_tokens) do
      {nil, opts} -> opts
      {value, opts} -> Keyword.put(opts, :max_completion_tokens, value)
    end
  end

  defp apply_token_limit_key(opts, _), do: opts

  defp apply_temperature_constraint(opts, %{temperature: :fixed_1}) do
    Keyword.put(opts, :temperature, 1.0)
  end

  defp apply_temperature_constraint(opts, %{temperature: :unsupported}) do
    Keyword.delete(opts, :temperature)
  end

  defp apply_temperature_constraint(opts, _), do: opts

  defp apply_sampling_constraint(opts, %{sampling: :unsupported}) do
    opts
    |> Keyword.delete(:top_p)
    |> Keyword.delete(:top_k)
  end

  defp apply_sampling_constraint(opts, _), do: opts

  defp apply_min_output_tokens(opts, %{min_output_tokens: min}) when is_integer(min) do
    token_key =
      if Keyword.has_key?(opts, :max_completion_tokens),
        do: :max_completion_tokens,
        else: :max_tokens

    current = Keyword.get(opts, token_key, 0)

    if current > 0 and current < min do
      Keyword.put(opts, token_key, min)
    else
      opts
    end
  end

  defp apply_min_output_tokens(opts, _), do: opts

  defp apply_reasoning_effort(opts, %{reasoning_effort: :required}) do
    if Keyword.has_key?(opts, :reasoning_effort) do
      opts
    else
      Keyword.put(opts, :reasoning_effort, :medium)
    end
  end

  defp apply_reasoning_effort(opts, %{reasoning_effort: :unsupported}) do
    Keyword.delete(opts, :reasoning_effort)
  end

  defp apply_reasoning_effort(opts, _), do: opts
end
