defmodule ReqLlmNext.Wire.OpenAIResponses do
  @moduledoc """
  Wire protocol for OpenAI Responses API.

  Handles /v1/responses endpoint for reasoning models (o1, o3, o4, GPT-5).
  This API uses different request/response formats than the Chat Completions API:

  - Input uses "input" array with typed items instead of "messages"
  - System messages become role: "developer"
  - Uses max_output_tokens instead of max_tokens
  - Supports reasoning config with effort levels
  - Streaming uses different event types (response.*)
  - Reasoning content is streamed as thinking deltas
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Tool

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: "/v1/responses"

  @doc "Returns the path for the Responses API endpoint."
  @spec path() :: String.t()
  def path, do: "/v1/responses"

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    %{
      model: model.id,
      input: encode_input(prompt),
      stream: true,
      stream_options: %{include_usage: true}
    }
    |> maybe_add(:max_output_tokens, get_max_tokens(opts))
    |> maybe_add(:reasoning, encode_reasoning_effort(Keyword.get(opts, :reasoning_effort)))
    |> maybe_add_tools(opts)
    |> maybe_add_tool_choice(opts)
    |> maybe_add_response_format(opts)
  end

  defp get_max_tokens(opts) do
    Keyword.get(opts, :max_output_tokens) ||
      Keyword.get(opts, :max_completion_tokens) ||
      Keyword.get(opts, :max_tokens)
  end

  defp encode_input(prompt) when is_binary(prompt) do
    [%{role: "user", content: [%{type: "input_text", text: prompt}]}]
  end

  defp encode_input(%ReqLlmNext.Context{messages: messages}) do
    messages
    |> Enum.reject(&tool_message?/1)
    |> Enum.map(&encode_input_message/1)
  end

  defp tool_message?(%ReqLlmNext.Context.Message{role: :tool}), do: true
  defp tool_message?(_), do: false

  defp encode_input_message(%ReqLlmNext.Context.Message{role: :system} = msg) do
    %{
      role: "developer",
      content: encode_input_content(msg.content, "input_text")
    }
  end

  defp encode_input_message(%ReqLlmNext.Context.Message{role: :assistant} = msg) do
    %{
      role: "assistant",
      content: encode_input_content(msg.content, "output_text")
    }
  end

  defp encode_input_message(%ReqLlmNext.Context.Message{role: role} = msg) do
    %{
      role: to_string(role),
      content: encode_input_content(msg.content, "input_text")
    }
  end

  defp encode_input_content(parts, content_type) when is_list(parts) do
    Enum.flat_map(parts, fn part ->
      case part do
        %{type: :text, text: text} -> [%{type: content_type, text: text}]
        %{type: :image_url, url: url} -> [%{type: "image_url", image_url: %{url: url}}]
        _ -> []
      end
    end)
  end

  defp encode_reasoning_effort(nil), do: nil
  defp encode_reasoning_effort(effort) when is_atom(effort), do: %{effort: Atom.to_string(effort)}
  defp encode_reasoning_effort(effort) when is_binary(effort), do: %{effort: effort}
  defp encode_reasoning_effort(_), do: nil

  defp maybe_add_tools(body, opts) do
    case Keyword.get(opts, :tools) do
      nil -> body
      [] -> body
      tools when is_list(tools) -> Map.put(body, :tools, Enum.map(tools, &encode_tool_def/1))
    end
  end

  defp encode_tool_def(%Tool{} = tool), do: encode_responses_tool(tool)
  defp encode_tool_def(tool) when is_map(tool), do: tool

  defp encode_responses_tool(%Tool{} = tool) do
    json_schema = Tool.to_schema(tool, :openai)
    function_def = json_schema["function"] || json_schema[:function]

    %{
      type: "function",
      name: function_def["name"] || function_def[:name],
      description: function_def["description"] || function_def[:description],
      parameters: function_def["parameters"] || function_def[:parameters],
      strict: tool.strict || true
    }
  end

  defp maybe_add_tool_choice(body, opts) do
    case Keyword.get(opts, :tool_choice) do
      nil ->
        body

      %{type: "function", function: %{name: name}} ->
        Map.put(body, :tool_choice, %{type: "function", name: name})

      %{type: "tool", name: name} ->
        Map.put(body, :tool_choice, %{type: "function", name: name})

      :auto ->
        Map.put(body, :tool_choice, "auto")

      :none ->
        Map.put(body, :tool_choice, "none")

      :required ->
        Map.put(body, :tool_choice, "required")

      "auto" ->
        Map.put(body, :tool_choice, "auto")

      "none" ->
        Map.put(body, :tool_choice, "none")

      "required" ->
        Map.put(body, :tool_choice, "required")

      _ ->
        body
    end
  end

  defp maybe_add_response_format(body, opts) do
    case {Keyword.get(opts, :operation), Keyword.get(opts, :compiled_schema)} do
      {:object, %{schema: schema}} when not is_nil(schema) ->
        json_schema = ReqLlmNext.Schema.to_json(schema)

        Map.put(body, :text, %{
          format: %{
            type: "json_schema",
            name: "object",
            strict: true,
            schema: json_schema
          }
        })

      _ ->
        body
    end
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    [
      max_output_tokens: [type: :pos_integer, doc: "Maximum output tokens to generate"],
      max_completion_tokens: [type: :pos_integer, doc: "Alias for max_output_tokens"],
      max_tokens: [type: :pos_integer, doc: "Alias for max_output_tokens (normalized)"],
      reasoning_effort: [
        type: {:in, [:minimal, :low, :medium, :high, "minimal", "low", "medium", "high"]},
        doc: "Control computation intensity for reasoning"
      ]
    ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_sse_event(%{data: "[DONE]"}, _model), do: [nil]

  def decode_sse_event(%{data: data}, model) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, %{"error" => error}} ->
        message = error["message"] || "Unknown API error"
        error_type = error["type"] || "api_error"
        [{:error, %{message: message, type: error_type, code: error["code"]}}]

      {:ok, decoded} ->
        decode_event(decoded, model)

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

  def decode_sse_event(%{data: data}, model) when is_map(data), do: decode_event(data, model)
  def decode_sse_event(_event, _model), do: []

  defp decode_event(data, model) do
    event_type = data["type"] || data["event"]

    case event_type do
      "response.output_text.delta" ->
        decode_text_delta(data)

      "response.reasoning.delta" ->
        decode_reasoning_delta(data)

      "response.output_item.added" ->
        decode_output_item_added(data)

      "response.function_call_arguments.delta" ->
        decode_function_call_args_delta(data)

      "response.function_call.delta" ->
        decode_function_call_delta(data)

      "response.usage" ->
        decode_usage_event(data, model)

      "response.completed" ->
        decode_completed_event(data, model)

      "response.incomplete" ->
        decode_incomplete_event(data)

      "response.output_text.done" ->
        []

      "response.output_item.done" ->
        []

      "response.function_call_arguments.done" ->
        []

      _ ->
        []
    end
  end

  defp decode_text_delta(%{"delta" => text}) when is_binary(text) and text != "", do: [text]
  defp decode_text_delta(_), do: []

  defp decode_reasoning_delta(%{"delta" => text}) when is_binary(text) and text != "" do
    [{:thinking, text}]
  end

  defp decode_reasoning_delta(_), do: []

  defp decode_output_item_added(%{"item" => %{"type" => "function_call"} = item} = data) do
    index = data["output_index"] || 0
    call_id = item["call_id"] || item["id"]
    name = item["name"]

    if name && name != "" do
      [{:tool_call_start, %{index: index, id: call_id, name: name}}]
    else
      []
    end
  end

  defp decode_output_item_added(_), do: []

  defp decode_function_call_args_delta(%{"delta" => fragment} = data)
       when is_binary(fragment) and fragment != "" do
    index = data["output_index"] || data["index"] || 0

    [{:tool_call_delta, %{index: index, function: %{"arguments" => fragment}}}]
  end

  defp decode_function_call_args_delta(_), do: []

  defp decode_function_call_delta(%{"delta" => delta} = data) when is_map(delta) do
    index = data["output_index"] || data["index"] || 0
    call_id = data["call_id"] || data["id"]

    chunks = []

    chunks =
      case delta["name"] do
        name when is_binary(name) and name != "" ->
          [{:tool_call_start, %{index: index, id: call_id, name: name}} | chunks]

        _ ->
          chunks
      end

    chunks =
      case delta["arguments"] do
        fragment when is_binary(fragment) and fragment != "" ->
          [{:tool_call_delta, %{index: index, function: %{"arguments" => fragment}}} | chunks]

        _ ->
          chunks
      end

    Enum.reverse(chunks)
  end

  defp decode_function_call_delta(_), do: []

  defp decode_usage_event(data, _model) do
    usage_data = data["usage"] || %{}

    input_tokens = usage_data["input_tokens"] || 0
    output_tokens = usage_data["output_tokens"] || 0

    reasoning_tokens =
      get_in(usage_data, ["output_tokens_details", "reasoning_tokens"]) ||
        usage_data["reasoning_tokens"] ||
        0

    cached_tokens =
      get_in(usage_data, ["input_tokens_details", "cached_tokens"]) || 0

    usage = %{
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: input_tokens + output_tokens
    }

    usage =
      if reasoning_tokens > 0,
        do: Map.put(usage, :reasoning_tokens, reasoning_tokens),
        else: usage

    usage =
      if cached_tokens > 0, do: Map.put(usage, :cache_read_tokens, cached_tokens), else: usage

    [{:usage, usage}]
  end

  defp decode_completed_event(data, _model) do
    response = data["response"] || %{}
    response_id = response["id"]
    usage_data = response["usage"]

    meta = %{terminal?: true, finish_reason: :stop}
    meta = if response_id, do: Map.put(meta, :response_id, response_id), else: meta

    if usage_data do
      input_tokens = usage_data["input_tokens"] || 0
      output_tokens = usage_data["output_tokens"] || 0

      reasoning_tokens =
        get_in(usage_data, ["output_tokens_details", "reasoning_tokens"]) ||
          usage_data["reasoning_tokens"] ||
          0

      usage = %{
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: usage_data["total_tokens"] || input_tokens + output_tokens
      }

      usage =
        if reasoning_tokens > 0,
          do: Map.put(usage, :reasoning_tokens, reasoning_tokens),
          else: usage

      [{:usage, usage}, {:meta, meta}]
    else
      [{:meta, meta}]
    end
  end

  defp decode_incomplete_event(data) do
    reason = data["reason"] || "incomplete"
    finish_reason = normalize_finish_reason(reason)

    [{:meta, %{terminal?: true, finish_reason: finish_reason}}]
  end

  defp normalize_finish_reason("stop"), do: :stop
  defp normalize_finish_reason("length"), do: :length
  defp normalize_finish_reason("max_tokens"), do: :length
  defp normalize_finish_reason("max_output_tokens"), do: :length
  defp normalize_finish_reason("tool_calls"), do: :tool_calls
  defp normalize_finish_reason("content_filter"), do: :content_filter
  defp normalize_finish_reason(_), do: :error

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
