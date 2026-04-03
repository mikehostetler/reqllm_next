defmodule ReqLlmNext.SurfacePreparation.CodexCLI do
  @moduledoc """
  Codex CLI surface-owned request preparation.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.Wire.CodexCLI, as: CodexWire

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, prompt, opts) do
    with :ok <- validate_no_tools(opts),
         {:ok, _prompt_text} <- CodexWire.prompt_text(prompt) do
      {:ok, opts}
    end
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_no_tools(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "Codex CLI does not support canonical tool calling in this MVP spike"
       )}
    end
  end
end
