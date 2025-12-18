defmodule ReqLlmNext.StreamResponse do
  @moduledoc """
  Stream response struct containing the lazy stream and model info.

  The stream can emit:
  - Strings (text content)
  - `{:thinking, text}` tuples (reasoning content from o-series models)
  - `{:tool_call_delta, map}` tuples (tool call fragments from OpenAI)
  - `{:tool_call_start, map}` tuples (tool call start from Anthropic)
  - `{:usage, map}` tuples (usage metrics)
  - `{:meta, map}` tuples (metadata like terminal?, finish_reason)
  - `nil` (stream termination)
  """

  alias ReqLlmNext.ToolCall

  defstruct [:stream, :model, :cancel_fn, :metadata_ref]

  @type t :: %__MODULE__{
          stream: Enumerable.t(),
          model: LLMDB.Model.t(),
          cancel_fn: (-> :ok) | nil,
          metadata_ref: reference() | nil
        }

  @doc """
  Cancel an in-progress stream.

  If the stream has a cancel function, it will be called to stop the stream.
  Returns :ok whether or not there was a cancel function.

  ## Examples

      {:ok, stream_resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello")
      ReqLlmNext.StreamResponse.cancel(stream_resp)

  """
  @spec cancel(t()) :: :ok
  def cancel(%__MODULE__{cancel_fn: nil}), do: :ok
  def cancel(%__MODULE__{cancel_fn: cancel_fn}) when is_function(cancel_fn, 0), do: cancel_fn.()

  @doc """
  Consume the stream and return the full text.

  Filters out non-text items (usage tuples, tool call deltas, etc.).
  """
  @spec text(t()) :: String.t()
  def text(%__MODULE__{stream: stream}) do
    stream
    |> Enum.filter(&is_binary/1)
    |> Enum.join("")
  end

  @doc """
  Extract thinking/reasoning content from stream.

  Returns concatenated reasoning text from `{:thinking, text}` tuples
  emitted by reasoning models (o-series, GPT-5).
  """
  @spec thinking(t()) :: String.t()
  def thinking(%__MODULE__{stream: stream}) do
    stream
    |> Enum.filter(fn
      {:thinking, _} -> true
      {:thinking_start, _} -> true
      _ -> false
    end)
    |> Enum.map_join("", fn
      {:thinking, text} -> text
      {:thinking_start, _} -> ""
    end)
  end

  @doc """
  Consume the stream and return usage metadata if present.
  """
  @spec usage(t()) :: map() | nil
  def usage(%__MODULE__{stream: stream}) do
    stream
    |> Enum.find_value(fn
      {:usage, usage} -> usage
      _ -> nil
    end)
  end

  @doc """
  Consume the stream and return the parsed JSON object.

  Joins all stream chunks and decodes as JSON.
  """
  @spec object(t()) :: map() | nil
  def object(%__MODULE__{} = resp) do
    json = text(resp)

    case Jason.decode(json) do
      {:ok, object} -> object
      {:error, _} -> nil
    end
  end

  @doc """
  Consume the stream and return assembled tool calls.

  Tool calls are streamed as deltas that need to be assembled into complete
  ToolCall structs.
  """
  @spec tool_calls(t()) :: [ToolCall.t()]
  def tool_calls(%__MODULE__{stream: stream}) do
    stream
    |> Enum.reduce(%{}, &accumulate_tool_call/2)
    |> Map.values()
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&finalize_tool_call/1)
  end

  defp accumulate_tool_call({:tool_call_delta, %{index: index} = delta}, acc) do
    Map.update(acc, index, init_tool_call_acc(delta), &merge_tool_call_delta(&1, delta))
  end

  defp accumulate_tool_call({:tool_call_start, %{index: index} = start}, acc) do
    Map.update(acc, index, init_tool_call_from_start(start), &merge_tool_call_start(&1, start))
  end

  defp accumulate_tool_call(_other, acc), do: acc

  defp init_tool_call_acc(%{id: id, function: function} = delta) when not is_nil(id) do
    %{
      index: delta.index,
      id: id,
      type: delta[:type] || "function",
      name: function["name"],
      arguments: function["arguments"] || ""
    }
  end

  defp init_tool_call_acc(delta) do
    %{
      index: delta.index,
      id: nil,
      type: delta[:type],
      name: nil,
      arguments: delta[:function]["arguments"] || ""
    }
  end

  defp init_tool_call_from_start(%{index: index, id: id, name: name}) do
    %{
      index: index,
      id: id,
      type: "function",
      name: name,
      arguments: ""
    }
  end

  defp merge_tool_call_delta(acc, %{function: function}) when is_map(function) do
    %{
      acc
      | name: acc.name || function["name"],
        arguments: acc.arguments <> (function["arguments"] || "")
    }
  end

  defp merge_tool_call_delta(acc, %{partial_json: json}) when is_binary(json) do
    %{acc | arguments: acc.arguments <> json}
  end

  defp merge_tool_call_delta(acc, %{id: id}) when not is_nil(id) do
    %{acc | id: id}
  end

  defp merge_tool_call_delta(acc, _delta), do: acc

  defp merge_tool_call_start(acc, %{id: id, name: name}) do
    %{acc | id: id || acc.id, name: name || acc.name}
  end

  defp finalize_tool_call(%{id: id, name: name, arguments: args}) do
    ToolCall.new(id, name, args)
  end
end
