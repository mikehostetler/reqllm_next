defmodule ReqLlmNext.Response do
  @moduledoc """
  High-level representation of an LLM turn.

  Always contains a Context (full conversation history including the newly-generated 
  assistant/tool messages) plus rich metadata and, when streaming, a lazy `Stream` 
  of chunks.

  This struct eliminates the need for manual message extraction and context building
  in multi-turn conversations and tool calling workflows.

  ## Examples

      {:ok, response} = ReqLlmNext.generate_text("anthropic:claude-3-sonnet", context)
      ReqLlmNext.Response.text(response)  #=> "Hello! I'm Claude."
      ReqLlmNext.Response.usage(response)  #=> %{input_tokens: 12, output_tokens: 4}

      # Multi-turn conversation (no manual context building)
      {:ok, response2} = ReqLlmNext.generate_text("anthropic:claude-3-sonnet", response.context)

  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{ContentPart, Message}

  @derive {Jason.Encoder, except: [:stream]}

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              model: Zoi.any(),
              context: Zoi.any(),
              message: Zoi.any() |> Zoi.nullish(),
              object: Zoi.map() |> Zoi.nullish() |> Zoi.default(nil),
              stream?: Zoi.boolean() |> Zoi.default(false),
              stream: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              usage: Zoi.map() |> Zoi.nullish(),
              finish_reason:
                Zoi.enum([:stop, :length, :tool_calls, :content_filter, :error]) |> Zoi.nullish(),
              provider_meta: Zoi.map() |> Zoi.default(%{}),
              error: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil)
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          id: String.t(),
          model: LLMDB.Model.t(),
          context: Context.t(),
          message: Message.t() | nil,
          object: map() | nil,
          stream?: boolean(),
          stream: Enumerable.t() | nil,
          usage: map() | nil,
          finish_reason: :stop | :length | :tool_calls | :content_filter | :error | nil,
          provider_meta: map(),
          error: Exception.t() | nil
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Response"
  def schema, do: @schema

  @doc """
  Extract text content from the response message.

  Returns the concatenated text from all content parts in the assistant message.
  Returns nil when no message is present.

  ## Examples

      iex> ReqLlmNext.Response.text(response)
      "Hello! I'm Claude and I can help you with questions."

  """
  @spec text(t()) :: String.t() | nil
  def text(%__MODULE__{message: nil}), do: nil

  def text(%__MODULE__{message: %Message{content: content}}) do
    content
    |> Enum.filter(&(&1.type == :text))
    |> Enum.map_join("", & &1.text)
  end

  @doc """
  Extract thinking/reasoning content from the response message.

  Returns the concatenated thinking content if the message contains thinking parts,
  empty string otherwise.

  ## Examples

      iex> ReqLlmNext.Response.thinking(response)
      "The user is asking about the weather..."

  """
  @spec thinking(t()) :: String.t() | nil
  def thinking(%__MODULE__{message: nil}), do: nil

  def thinking(%__MODULE__{message: %Message{content: content}}) do
    content
    |> Enum.filter(&(&1.type == :thinking))
    |> Enum.map_join("", & &1.text)
  end

  @doc """
  Extract tool calls from the response message.

  Returns a list of tool calls if the message contains them, empty list otherwise.

  ## Examples

      iex> ReqLlmNext.Response.tool_calls(response)
      [%ToolCall{id: "call_1", function: %{name: "get_weather", arguments: "..."}}]

  """
  @spec tool_calls(t()) :: [ReqLlmNext.ToolCall.t()]
  def tool_calls(%__MODULE__{message: nil}), do: []

  def tool_calls(%__MODULE__{message: %Message{tool_calls: tool_calls}})
      when is_list(tool_calls) do
    tool_calls
  end

  def tool_calls(%__MODULE__{message: %Message{tool_calls: nil}}), do: []

  @doc """
  Get usage statistics for this response.

  ## Examples

      iex> ReqLlmNext.Response.usage(response)
      %{input_tokens: 12, output_tokens: 8, total_tokens: 20}

  """
  @spec usage(t()) :: map() | nil
  def usage(%__MODULE__{usage: usage}), do: usage

  @doc """
  Get reasoning token count from the response usage.

  Returns the number of reasoning tokens used by reasoning models (o1, o3, etc.)
  during their internal thinking process. Returns 0 if no reasoning tokens were used.

  ## Examples

      iex> ReqLlmNext.Response.reasoning_tokens(response)
      64

  """
  @spec reasoning_tokens(t()) :: integer()
  def reasoning_tokens(%__MODULE__{usage: %{reasoning_tokens: tokens}}) when is_integer(tokens),
    do: tokens

  def reasoning_tokens(%__MODULE__{usage: usage}) when is_map(usage) do
    usage[:reasoning_tokens] || usage["reasoning_tokens"] || usage[:reasoning] ||
      usage["reasoning"] || get_in(usage, [:completion_tokens_details, :reasoning_tokens]) ||
      get_in(usage, ["completion_tokens_details", "reasoning_tokens"]) || 0
  end

  def reasoning_tokens(%__MODULE__{}), do: 0

  @doc """
  Check if the response completed successfully without errors.

  ## Examples

      iex> ReqLlmNext.Response.ok?(response)
      true

  """
  @spec ok?(t()) :: boolean()
  def ok?(%__MODULE__{error: nil}), do: true
  def ok?(%__MODULE__{error: _error}), do: false

  @doc """
  Create a stream of text content chunks from a streaming response.

  Only yields content from text chunks, filtering out metadata and other chunk types.

  ## Examples

      response
      |> ReqLlmNext.Response.text_stream()
      |> Stream.each(&IO.write/1)
      |> Stream.run()

  """
  @spec text_stream(t()) :: Enumerable.t()
  def text_stream(%__MODULE__{stream?: false}), do: []
  def text_stream(%__MODULE__{stream: nil}), do: []

  def text_stream(%__MODULE__{stream: stream}) do
    Stream.filter(stream, &is_binary/1)
  end

  @doc """
  Create a stream of structured objects from a streaming response.

  Only yields valid objects from tool call stream chunks.

  ## Examples

      response
      |> ReqLlmNext.Response.object_stream()
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()

  """
  @spec object_stream(t()) :: Enumerable.t()
  def object_stream(%__MODULE__{stream?: false}), do: []
  def object_stream(%__MODULE__{stream: nil}), do: []

  def object_stream(%__MODULE__{stream: stream}) do
    stream
    |> Stream.filter(fn
      {:tool_call_delta, _} -> true
      {:tool_call_start, _} -> true
      _ -> false
    end)
  end

  @doc """
  Materialize a streaming response into a complete response.

  Consumes the entire stream, builds the complete message, and returns
  a new response with the stream consumed and message populated.

  ## Examples

      {:ok, complete_response} = ReqLlmNext.Response.join_stream(streaming_response)

  """
  @spec join_stream(t()) :: {:ok, t()} | {:error, term()}
  def join_stream(%__MODULE__{stream?: false} = response), do: {:ok, response}
  def join_stream(%__MODULE__{stream: nil} = response), do: {:ok, response}

  def join_stream(%__MODULE__{stream: stream, context: context} = response) do
    {text_parts, tool_calls, usage} = collect_stream(stream)

    text = Enum.join(text_parts, "")

    message =
      if text != "" or tool_calls != [] do
        tool_calls_normalized = if tool_calls == [], do: nil, else: tool_calls

        %Message{
          role: :assistant,
          content: [ContentPart.text(text)],
          tool_calls: tool_calls_normalized
        }
      else
        nil
      end

    updated_context =
      if message do
        Context.append(context, message)
      else
        context
      end

    {:ok,
     %{
       response
       | stream?: false,
         stream: nil,
         message: message,
         context: updated_context,
         usage: usage || response.usage
     }}
  rescue
    e -> {:error, e}
  end

  defp collect_stream(stream) do
    stream
    |> Enum.reduce({[], %{}, nil}, fn
      text, {texts, tool_acc, usage} when is_binary(text) ->
        {[text | texts], tool_acc, usage}

      {:usage, usage_map}, {texts, tool_acc, _usage} ->
        {texts, tool_acc, usage_map}

      {:tool_call_delta, %{index: index} = delta}, {texts, tool_acc, usage} ->
        updated = Map.update(tool_acc, index, init_tool_call(delta), &merge_tool_call(&1, delta))
        {texts, updated, usage}

      {:tool_call_start, %{index: index} = start}, {texts, tool_acc, usage} ->
        updated =
          Map.update(tool_acc, index, init_tool_call_from_start(start), &merge_start(&1, start))

        {texts, updated, usage}

      _other, acc ->
        acc
    end)
    |> then(fn {texts, tool_acc, usage} ->
      tool_calls =
        tool_acc
        |> Map.values()
        |> Enum.sort_by(& &1.index)
        |> Enum.map(&finalize_tool_call/1)

      {Enum.reverse(texts), tool_calls, usage}
    end)
  end

  defp init_tool_call(%{id: id, function: function} = delta) when not is_nil(id) do
    %{
      index: delta.index,
      id: id,
      type: delta[:type] || "function",
      name: function["name"],
      arguments: function["arguments"] || ""
    }
  end

  defp init_tool_call(delta) do
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

  defp merge_tool_call(acc, %{function: function}) when is_map(function) do
    %{
      acc
      | name: acc.name || function["name"],
        arguments: acc.arguments <> (function["arguments"] || "")
    }
  end

  defp merge_tool_call(acc, %{partial_json: json}) when is_binary(json) do
    %{acc | arguments: acc.arguments <> json}
  end

  defp merge_tool_call(acc, %{id: id}) when not is_nil(id) do
    %{acc | id: id}
  end

  defp merge_tool_call(acc, _delta), do: acc

  defp merge_start(acc, %{id: id, name: name}) do
    %{acc | id: id || acc.id, name: name || acc.name}
  end

  defp finalize_tool_call(%{id: id, name: name, arguments: args}) do
    ReqLlmNext.ToolCall.new(id, name, args)
  end

  @doc """
  Get the object from the response.
  """
  @spec object(t()) :: map() | nil
  def object(%__MODULE__{object: object}), do: object

  @doc """
  Get the finish reason for this response.
  """
  @spec finish_reason(t()) :: :stop | :length | :tool_calls | :content_filter | :error | nil
  def finish_reason(%__MODULE__{finish_reason: reason}), do: reason

  @doc """
  Build a response with context evolution.

  The context in the response includes all original messages plus the new assistant message.
  This is the preferred way to construct responses in the Executor.

  ## Parameters

    * `model` - The LLMDB.Model struct
    * `original_context` - The input context before the response
    * `message` - The assistant message from the response
    * `opts` - Optional fields: :id, :object, :usage, :finish_reason, :provider_meta

  ## Examples

      response = Response.build(model, context, message, usage: %{input_tokens: 10})

  """
  @spec build(LLMDB.Model.t(), Context.t(), Message.t() | nil, keyword()) :: t()
  def build(model, original_context, message, opts \\ []) do
    evolved_context =
      if message do
        Context.append(original_context, message)
      else
        original_context
      end

    %__MODULE__{
      id: opts[:id] || generate_id(),
      model: model,
      context: evolved_context,
      message: message,
      object: opts[:object],
      usage: opts[:usage],
      finish_reason: opts[:finish_reason],
      provider_meta: opts[:provider_meta] || %{}
    }
  end

  defp generate_id do
    "resp_" <> (:crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false))
  end
end
