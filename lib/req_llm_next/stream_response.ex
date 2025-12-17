defmodule ReqLlmNext.StreamResponse do
  @moduledoc """
  Stream response struct containing the lazy stream and model info.
  """

  defstruct [:stream, :model]

  @type t :: %__MODULE__{
          stream: Enumerable.t(),
          model: LLMDB.Model.t()
        }

  @doc """
  Consume the stream and return the full text.
  """
  @spec text(t()) :: String.t()
  def text(%__MODULE__{stream: stream}) do
    stream
    |> Enum.join("")
  end
end
