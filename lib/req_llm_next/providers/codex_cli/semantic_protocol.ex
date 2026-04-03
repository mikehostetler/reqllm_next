defmodule ReqLlmNext.SemanticProtocols.CodexCLI do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.Response.Usage

  @impl ReqLlmNext.SemanticProtocol
  def decode_event(
        %{"type" => "item.completed", "item" => %{"type" => "agent_message", "text" => text}},
        _model
      )
      when is_binary(text) and text != "" do
    [text]
  end

  def decode_event(%{"type" => "turn.completed", "usage" => usage}, model) when is_map(usage) do
    [
      {:usage, normalize_usage(usage, model)},
      {:meta, %{finish_reason: :stop, terminal?: true}}
    ]
  end

  def decode_event(
        %{
          "type" => "req_llm_next.codex_cli_error",
          "message" => message,
          "exit_status" => exit_status
        },
        _model
      )
      when is_binary(message) do
    [{:error, %{message: message, type: "cli_error", exit_status: exit_status}}]
  end

  def decode_event(%{"type" => "error", "message" => message}, _model) when is_binary(message) do
    [{:error, %{message: message, type: "cli_error"}}]
  end

  def decode_event(_event, _model), do: []

  defp normalize_usage(raw_usage, model) do
    %{
      "input_tokens" => Map.get(raw_usage, "input_tokens", 0),
      "output_tokens" => Map.get(raw_usage, "output_tokens", 0),
      "cache_read_input_tokens" => Map.get(raw_usage, "cached_input_tokens")
    }
    |> Usage.normalize(model)
  end
end
