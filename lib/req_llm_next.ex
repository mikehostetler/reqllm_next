defmodule ReqLlmNext do
  @moduledoc """
  ReqLLM v2 tracer bullet - minimal streaming implementation for gpt-4o-mini.

  This is a focused end-to-end implementation demonstrating the v2 architecture
  with a single model. Uses Finch directly for streaming.

  ## Usage

      {:ok, stream} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello!")
      stream |> Enum.each(&IO.write/1)

  """

  alias ReqLlmNext.{Executor, StreamResponse}

  @doc """
  Stream text from gpt-4o-mini.

  Returns a stream of text chunks that can be consumed lazily.

  ## Examples

      {:ok, stream} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Tell me a joke")
      stream |> Enum.each(&IO.write/1)

  """
  @spec stream_text(String.t(), String.t(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_text(model_spec, prompt, opts \\ []) do
    Executor.stream_text(model_spec, prompt, opts)
  end
end
