defmodule ReqLlmNext.Response.Usage do
  @moduledoc """
  Normalize usage metrics from different providers into a canonical format.

  Handles the various usage formats from OpenAI, Anthropic, Google, and other providers,
  normalizing them into a consistent structure with input_tokens, output_tokens, and
  optional reasoning_tokens.
  """

  @type normalized_usage :: %{
          required(:input_tokens) => non_neg_integer(),
          required(:output_tokens) => non_neg_integer(),
          required(:total_tokens) => non_neg_integer(),
          optional(:reasoning_tokens) => non_neg_integer(),
          optional(:cache_read_tokens) => non_neg_integer(),
          optional(:cache_creation_tokens) => non_neg_integer()
        }

  @doc """
  Normalize raw usage data from a provider into a canonical format.

  ## OpenAI Format

      %{
        "prompt_tokens" => 12,
        "completion_tokens" => 8,
        "total_tokens" => 20,
        "completion_tokens_details" => %{
          "reasoning_tokens" => 64
        }
      }

  ## Anthropic Format

      %{
        "input_tokens" => 12,
        "output_tokens" => 8,
        "cache_read_input_tokens" => 0,
        "cache_creation_input_tokens" => 0
      }

  ## Returns

  A normalized map with consistent keys:
  - `:input_tokens` - Number of input/prompt tokens
  - `:output_tokens` - Number of output/completion tokens
  - `:total_tokens` - Sum of input and output tokens
  - `:reasoning_tokens` - (optional) Reasoning tokens for o1/o3 models
  - `:cache_read_tokens` - (optional) Cached tokens read
  - `:cache_creation_tokens` - (optional) Cached tokens created

  """
  @spec normalize(map() | nil, LLMDB.Model.t()) :: normalized_usage() | nil
  def normalize(nil, _model), do: nil
  def normalize(raw_usage, _model) when raw_usage == %{}, do: nil

  def normalize(raw_usage, _model) when is_map(raw_usage) do
    cond do
      openai_format?(raw_usage) -> normalize_openai(raw_usage)
      anthropic_format?(raw_usage) -> normalize_anthropic(raw_usage)
      true -> normalize_generic(raw_usage)
    end
  end

  defp openai_format?(usage) do
    Map.has_key?(usage, "prompt_tokens") or Map.has_key?(usage, :prompt_tokens)
  end

  defp anthropic_format?(usage) do
    Map.has_key?(usage, "input_tokens") or Map.has_key?(usage, :input_tokens) or
      Map.has_key?(usage, "output_tokens") or Map.has_key?(usage, :output_tokens) or
      Map.has_key?(usage, "cache_read_input_tokens") or
      Map.has_key?(usage, "cache_creation_input_tokens")
  end

  defp normalize_openai(usage) do
    prompt_tokens = get_value(usage, ["prompt_tokens", :prompt_tokens], 0)
    completion_tokens = get_value(usage, ["completion_tokens", :completion_tokens], 0)

    total_tokens =
      get_value(usage, ["total_tokens", :total_tokens], prompt_tokens + completion_tokens)

    base = %{
      input_tokens: prompt_tokens,
      output_tokens: completion_tokens,
      total_tokens: total_tokens
    }

    base
    |> maybe_add_reasoning_tokens(usage)
    |> maybe_add_cached_tokens(usage)
  end

  defp normalize_anthropic(usage) do
    input_tokens = get_value(usage, ["input_tokens", :input_tokens], 0)
    output_tokens = get_value(usage, ["output_tokens", :output_tokens], 0)

    base = %{
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: input_tokens + output_tokens
    }

    cache_read = get_value(usage, ["cache_read_input_tokens", :cache_read_input_tokens], nil)

    cache_creation =
      get_value(usage, ["cache_creation_input_tokens", :cache_creation_input_tokens], nil)

    base
    |> maybe_put(:cache_read_tokens, cache_read)
    |> maybe_put(:cache_creation_tokens, cache_creation)
  end

  defp normalize_generic(usage) do
    input_tokens =
      get_value(usage, ["input_tokens", :input_tokens, "prompt_tokens", :prompt_tokens], 0)

    output_tokens =
      get_value(
        usage,
        ["output_tokens", :output_tokens, "completion_tokens", :completion_tokens],
        0
      )

    total_tokens =
      get_value(usage, ["total_tokens", :total_tokens], input_tokens + output_tokens)

    %{
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: total_tokens
    }
    |> maybe_add_reasoning_tokens(usage)
  end

  defp maybe_add_reasoning_tokens(normalized, usage) do
    reasoning =
      get_in(usage, ["completion_tokens_details", "reasoning_tokens"]) ||
        get_in(usage, [:completion_tokens_details, :reasoning_tokens]) ||
        get_value(usage, ["reasoning_tokens", :reasoning_tokens], nil)

    maybe_put(normalized, :reasoning_tokens, reasoning)
  end

  defp maybe_add_cached_tokens(normalized, usage) do
    cached_tokens =
      get_in(usage, ["prompt_tokens_details", "cached_tokens"]) ||
        get_in(usage, [:prompt_tokens_details, :cached_tokens])

    maybe_put(normalized, :cache_read_tokens, cached_tokens)
  end

  defp get_value(map, keys, default) when is_list(keys) do
    Enum.find_value(keys, default, fn key -> Map.get(map, key) end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, 0), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
