defmodule ReqLlmNext.Adapters.ModelAdapter do
  @moduledoc """
  Behaviour for per-model customizations.

  Adapters handle the ~5% of models that need special handling beyond what
  LLMDB metadata and constraints can express. They form a pipeline that
  transforms options before they reach the wire protocol layer.

  ## Use Cases

  - Parameter renaming (max_tokens -> max_completion_tokens)
  - Injecting required parameters (reasoning_effort for o-series)
  - Stripping unsupported parameters (temperature for reasoning models)
  - Response transformation (extracting reasoning tokens)

  ## Pipeline Execution

  Adapters are executed in order. Each adapter receives the options from
  the previous adapter and returns transformed options.
  """

  @type opts :: keyword()

  @doc """
  Returns true if this adapter should apply to the given model.
  """
  @callback matches?(LLMDB.Model.t()) :: boolean()

  @doc """
  Transforms request options before encoding.
  Called after Constraints.apply, before wire encoding.
  """
  @callback transform_opts(LLMDB.Model.t(), opts()) :: opts()

  @optional_callbacks []
end
