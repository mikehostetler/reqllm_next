defmodule ReqLlmNext.Wire.OpenAIChat do
  @moduledoc """
  Wire protocol for OpenAI Chat Completions API.

  Handles encoding requests and decoding SSE events for /v1/chat/completions endpoint.
  Works with any OpenAI-compatible provider (OpenAI, Groq, OpenRouter, xAI, etc.)
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Response.Usage
  alias ReqLlmNext.{Tool, ToolCall}

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: "/chat/completions"

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    %{
      model: model.id,
      messages: encode_messages(prompt),
      stream: true,
      stream_options: %{include_usage: true}
    }
    |> maybe_add(:max_tokens, Keyword.get(opts, :max_tokens))
    |> maybe_add(:temperature, Keyword.get(opts, :temperature))
    |> maybe_add_response_format(opts)
    |> maybe_add_tools(opts)
    |> maybe_add_tool_choice(opts)
  end

  defp encode_messages(prompt) when is_binary(prompt) do
    [%{role: "user", content: prompt}]
  end

  defp encode_messages(%ReqLlmNext.Context{messages: messages}) do
    Enum.map(messages, &encode_message/1)
  end

  defp encode_message(%ReqLlmNext.Context.Message{role: :tool} = msg) do
    %{
      role: "tool",
      tool_call_id: msg.tool_call_id,
      content: encode_content(msg.content)
    }
  end

  defp encode_message(%ReqLlmNext.Context.Message{role: :assistant, tool_calls: tool_calls} = msg)
       when is_list(tool_calls) and tool_calls != [] do
    %{
      role: "assistant",
      content: encode_content(msg.content),
      tool_calls: Enum.map(tool_calls, &encode_tool_call/1)
    }
  end

  defp encode_message(%ReqLlmNext.Context.Message{role: role, content: content}) do
    %{
      role: to_string(role),
      content: encode_content(content)
    }
  end

  defp encode_tool_call(%ToolCall{id: id, type: type, function: function}) do
    %{
      id: id,
      type: type,
      function: %{
        name: function.name,
        arguments: function.arguments
      }
    }
  end

  defp encode_content([%{type: :text, text: text}]) when is_binary(text), do: text

  defp encode_content(parts) when is_list(parts) do
    Enum.map(parts, &encode_content_part/1)
  end

  defp encode_content_part(%{type: :text, text: text}), do: %{type: "text", text: text}

  defp encode_content_part(%{type: :image_url, url: url}),
    do: %{type: "image_url", image_url: %{url: url}}

  defp maybe_add_response_format(body, opts) do
    case {Keyword.get(opts, :operation), Keyword.get(opts, :compiled_schema)} do
      {:object, %{schema: schema}} when not is_nil(schema) ->
        json_schema = ReqLlmNext.Schema.to_json(schema)

        Map.put(body, :response_format, %{
          type: "json_schema",
          json_schema: %{
            name: "object",
            strict: true,
            schema: json_schema
          }
        })

      _ ->
        body
    end
  end

  defp maybe_add_tools(body, opts) do
    case Keyword.get(opts, :tools) do
      nil -> body
      [] -> body
      tools when is_list(tools) -> Map.put(body, :tools, Enum.map(tools, &encode_tool_def/1))
    end
  end

  defp encode_tool_def(%Tool{} = tool), do: Tool.to_schema(tool, :openai)
  defp encode_tool_def(tool) when is_map(tool), do: tool

  defp maybe_add_tool_choice(body, opts) do
    case Keyword.get(opts, :tool_choice) do
      nil ->
        body

      %{type: "tool", name: name} ->
        Map.put(body, :tool_choice, %{type: "function", function: %{name: name}})

      choice ->
        Map.put(body, :tool_choice, choice)
    end
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    [
      max_tokens: [type: :pos_integer, doc: "Maximum tokens to generate"],
      temperature: [type: :float, doc: "Sampling temperature (0.0-2.0)"],
      top_p: [type: :float, doc: "Nucleus sampling parameter"],
      frequency_penalty: [type: :float, doc: "Frequency penalty (-2.0 to 2.0)"],
      presence_penalty: [type: :float, doc: "Presence penalty (-2.0 to 2.0)"]
    ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_sse_event(%{data: "[DONE]"}, _model), do: [nil]

  def decode_sse_event(%{data: data}, model) do
    case Jason.decode(data) do
      {:ok, %{"error" => error}} ->
        message = error["message"] || "Unknown API error"
        error_type = error["type"] || "api_error"
        [{:error, %{message: message, type: error_type, code: error["code"]}}]

      {:ok, %{"choices" => [%{"delta" => delta} | _]} = payload} ->
        content = decode_delta(delta)
        usage = maybe_extract_usage(payload, model)
        content ++ usage

      {:ok, %{"usage" => usage} = _payload} when is_map(usage) ->
        [{:usage, Usage.normalize(usage, model)}]

      {:ok, _} ->
        []

      {:error, decode_error} ->
        [
          {:error,
           %{
             message: "Failed to decode SSE event: #{inspect(decode_error)}",
             type: "decode_error"
           }}
        ]
    end
  end

  defp maybe_extract_usage(%{"usage" => usage}, model) when is_map(usage) do
    [{:usage, Usage.normalize(usage, model)}]
  end

  defp maybe_extract_usage(_payload, _model), do: []

  defp decode_delta(%{"content" => content}) when is_binary(content), do: [content]

  defp decode_delta(%{"tool_calls" => tool_calls}) when is_list(tool_calls) do
    Enum.map(tool_calls, fn tc ->
      {:tool_call_delta,
       %{
         index: tc["index"],
         id: tc["id"],
         type: tc["type"],
         function: tc["function"]
       }}
    end)
  end

  defp decode_delta(_), do: []

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
