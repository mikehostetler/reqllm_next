defmodule ReqLlmNext do
  @moduledoc """
  ReqLLM v2 - A metadata-driven LLM client library for Elixir.

  ReqLlmNext provides a unified interface for working with multiple LLM providers
  (OpenAI, Anthropic, and more) through a clean, metadata-driven architecture.

  ## Architecture Overview

  ReqLlmNext uses a 6-step pipeline for all operations:

  1. **ModelResolver** - Resolves model specs via LLMDB + config overrides
  2. **Validation** - Validates modalities and operation compatibility
  3. **Constraints** - Applies parameter transforms from model metadata
  4. **Adapter Pipeline** - Handles per-model customizations (reasoning, thinking, etc.)
  5. **Wire Protocol** - JSON encoding/decoding per API family
  6. **Provider HTTP** - Base URL, authentication, Finch orchestration

  ## Quick Start

      # Simple text generation
      {:ok, response} = ReqLlmNext.generate_text("openai:gpt-4o-mini", "Hello!")
      ReqLlmNext.Response.text(response)
      #=> "Hello! How can I help you today?"

      # Streaming responses
      {:ok, stream_resp} = ReqLlmNext.stream_text("anthropic:claude-3-5-sonnet", "Tell me a story")
      stream_resp.stream |> Enum.each(&IO.write/1)

      # Structured output generation
      schema = [name: [type: :string, required: true], age: [type: :integer]]
      {:ok, response} = ReqLlmNext.generate_object("openai:gpt-4o-mini", "Generate a person", schema)
      response.object
      #=> %{"name" => "Alice", "age" => 30}

      # Embeddings
      {:ok, embedding} = ReqLlmNext.embed("openai:text-embedding-3-small", "Hello world")
      length(embedding)
      #=> 1536

      # Multi-turn conversations
      context = ReqLlmNext.context([
        ReqLlmNext.Context.system("You are a helpful assistant"),
        ReqLlmNext.Context.user("What's the capital of France?")
      ])
      {:ok, response} = ReqLlmNext.generate_text("openai:gpt-4o-mini", context)

      # Continue the conversation using the evolved context
      follow_up = ReqLlmNext.Context.append(response.context, ReqLlmNext.Context.user("What about Germany?"))
      {:ok, response2} = ReqLlmNext.generate_text("openai:gpt-4o-mini", follow_up)

  ## Supported Providers

  - **OpenAI**: `openai:gpt-4o`, `openai:gpt-4o-mini`, `openai:o1`, `openai:o3-mini`, etc.
  - **Anthropic**: `anthropic:claude-3-5-sonnet`, `anthropic:claude-3-5-haiku`, etc.
  - **OpenAI-Compatible**: Any provider using OpenAI's API format

  ## Configuration

  ReqLlmNext loads API keys from standard sources in order of precedence:

  1. Per-request `:api_key` option
  2. Application config: `config :req_llm_next, :anthropic_api_key, "..."`
  3. System environment: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`

  For programmatic key management:

      ReqLlmNext.put_key(:anthropic_api_key, "sk-ant-...")
      ReqLlmNext.get_key(:anthropic_api_key)

  ## Response Struct

  All text generation functions return a `ReqLlmNext.Response` struct:

  - `response.context` - Evolved context with the new message appended
  - `response.message` - The assistant's message
  - `response.object` - Parsed object (for generate_object)
  - `response.usage` - Token usage statistics
  - `response.finish_reason` - Why the response ended (:stop, :length, :tool_calls)

  Helper functions:

      ReqLlmNext.Response.text(response)      # Get text content
      ReqLlmNext.Response.thinking(response)  # Get thinking/reasoning content
      ReqLlmNext.Response.tool_calls(response) # Get tool calls
      ReqLlmNext.Response.usage(response)     # Get usage stats
      ReqLlmNext.Response.ok?(response)       # Check for errors

  ## StreamResponse Struct

  Streaming functions return a `ReqLlmNext.StreamResponse`:

      {:ok, stream_resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Hello")

      # Consume as stream
      stream_resp.stream |> Enum.each(&IO.write/1)

      # Or use helpers
      text = ReqLlmNext.StreamResponse.text(stream_resp)
      object = ReqLlmNext.StreamResponse.object(stream_resp)
      ReqLlmNext.StreamResponse.cancel(stream_resp)  # Cancel in-progress stream

  ## Error Types

  All errors are structured using Splode:

  - `ReqLlmNext.Error.Invalid.Parameter` - Invalid input parameters
  - `ReqLlmNext.Error.Invalid.Provider` - Unknown provider
  - `ReqLlmNext.Error.Invalid.Capability` - Unsupported model capability
  - `ReqLlmNext.Error.API.Request` - HTTP/network errors
  - `ReqLlmNext.Error.API.Response` - Provider response errors
  - `ReqLlmNext.Error.API.Stream` - Streaming errors
  - `ReqLlmNext.Error.API.SchemaValidation` - Object validation errors
  - `ReqLlmNext.Error.Validation.Error` - Validation failures
  """

  alias ReqLlmNext.{
    Context,
    Executor,
    ModelResolver,
    Providers,
    Response,
    Schema,
    StreamResponse,
    Tool
  }

  @doc """
  Generate text from a model (non-streaming).

  Internally buffers the streaming response to return the full text.

  ## Examples

      {:ok, %{text: text}} = ReqLlmNext.generate_text("openai:gpt-4o-mini", "Tell me a joke")
      IO.puts(text)

  """
  @spec generate_text(String.t(), String.t(), keyword()) ::
          {:ok, %{text: String.t(), model: LLMDB.Model.t()}} | {:error, term()}
  def generate_text(model_spec, prompt, opts \\ []) do
    Executor.generate_text(model_spec, prompt, opts)
  end

  @doc """
  Stream text from a model.

  Returns a StreamResponse containing a lazy stream of text chunks.

  ## Examples

      {:ok, resp} = ReqLlmNext.stream_text("openai:gpt-4o-mini", "Tell me a joke")
      resp.stream |> Enum.each(&IO.write/1)

      # Or get full text from stream
      text = ReqLlmNext.StreamResponse.text(resp)

  """
  @spec stream_text(String.t(), String.t(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_text(model_spec, prompt, opts \\ []) do
    Executor.stream_text(model_spec, prompt, opts)
  end

  @doc """
  Stream structured JSON object from a model using a schema.

  Returns a StreamResponse containing a lazy stream of JSON text chunks.
  When joined, the chunks form valid JSON matching the provided schema.

  ## Examples

      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      ]
      {:ok, resp} = ReqLlmNext.stream_object("openai:gpt-4o-mini", "Generate a person", schema)

      # Get complete JSON and decode
      json = resp.stream |> Enum.join()
      {:ok, object} = Jason.decode(json)

      # Or use helper
      object = ReqLlmNext.StreamResponse.object(resp)

  """
  @spec stream_object(String.t(), String.t(), term(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_object(model_spec, prompt, object_schema, opts \\ []) do
    Executor.stream_object(model_spec, prompt, object_schema, opts)
  end

  @doc """
  Generate a structured object from the model (non-streaming).

  Returns a Response with the `.object` field populated with the validated result.
  Internally buffers the streaming response to return the complete object.

  ## Examples

      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      ]
      {:ok, resp} = ReqLlmNext.generate_object("openai:gpt-4o-mini", "Generate a person", schema)
      resp.object
      #=> %{"name" => "John", "age" => 30}

  """
  @spec generate_object(String.t(), String.t() | Context.t(), keyword() | map(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def generate_object(model_spec, prompt, schema, opts \\ []) do
    Executor.generate_object(model_spec, prompt, schema, opts)
  end

  @doc """
  Generate a structured object from the model (non-streaming).

  Bang version that raises on error.

  ## Examples

      schema = [name: [type: :string, required: true]]
      resp = ReqLlmNext.generate_object!("openai:gpt-4o-mini", "Generate a person", schema)
      resp.object["name"]

  """
  @spec generate_object!(String.t(), String.t() | Context.t(), keyword() | map(), keyword()) ::
          Response.t()
  def generate_object!(model_spec, prompt, schema, opts \\ []) do
    case generate_object(model_spec, prompt, schema, opts) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end

  # ===========================================================================
  # Configuration API
  # ===========================================================================

  @doc """
  Stores an API key in application configuration.

  ## Parameters

    * `key` - The configuration key (atom)
    * `value` - The value to store

  ## Examples

      ReqLlmNext.put_key(:anthropic_api_key, "sk-ant-...")

  """
  @spec put_key(atom(), term()) :: :ok
  def put_key(key, value) when is_atom(key) do
    Application.put_env(:req_llm_next, key, value)
    :ok
  end

  def put_key(_key, _value) do
    raise ArgumentError, "put_key/2 expects an atom key like :anthropic_api_key"
  end

  @doc """
  Gets an API key from application config or system environment.

  ## Parameters

    * `key` - The configuration key (atom or string)

  ## Examples

      ReqLlmNext.get_key(:anthropic_api_key)
      ReqLlmNext.get_key("ANTHROPIC_API_KEY")

  """
  @spec get_key(atom() | String.t()) :: String.t() | nil
  def get_key(key) when is_atom(key), do: Application.get_env(:req_llm_next, key)
  def get_key(key) when is_binary(key), do: System.get_env(key)

  # ===========================================================================
  # Context API
  # ===========================================================================

  @doc """
  Creates a context from a list of messages, a single message struct, or a string.

  ## Parameters

    * `messages` - List of Message structs, a single Message struct, or a string

  ## Examples

      messages = [
        ReqLlmNext.Context.system("You are helpful"),
        ReqLlmNext.Context.user("Hello!")
      ]
      ctx = ReqLlmNext.context(messages)

      # Single message struct
      ctx = ReqLlmNext.context(ReqLlmNext.Context.user("Hello!"))

      # String prompt
      ctx = ReqLlmNext.context("Hello!")

  """
  @spec context([struct()] | struct() | String.t()) :: Context.t()
  def context(message_list) when is_list(message_list) do
    Context.new(message_list)
  end

  def context(%ReqLlmNext.Context.Message{} = message) do
    Context.new([message])
  end

  def context(prompt) when is_binary(prompt) do
    Context.new([Context.user(prompt)])
  end

  # ===========================================================================
  # Provider API
  # ===========================================================================

  @doc """
  Gets a provider module from the registry.

  ## Parameters

    * `provider` - Provider identifier (atom)

  ## Examples

      ReqLlmNext.provider(:anthropic)
      #=> {:ok, ReqLlmNext.Providers.Anthropic}

      ReqLlmNext.provider(:unknown)
      #=> {:error, {:unknown_provider, :unknown}}

  """
  @spec provider(atom()) :: {:ok, module()} | {:error, term()}
  def provider(provider_id) when is_atom(provider_id) do
    Providers.get(provider_id)
  end

  # ===========================================================================
  # Model API
  # ===========================================================================

  @doc """
  Creates a model struct from various specifications.

  ## Parameters

    * `model_spec` - Model specification in various formats:
      - String format: `"anthropic:claude-3-sonnet"`
      - Tuple format: `{:anthropic, "claude-3-sonnet", temperature: 0.7}`
      - Model struct: `%LLMDB.Model{}`

  ## Examples

      ReqLlmNext.model("anthropic:claude-3-sonnet")
      #=> {:ok, %LLMDB.Model{provider: :anthropic, id: "claude-3-sonnet"}}

      ReqLlmNext.model({:anthropic, "claude-3-sonnet", temperature: 0.5})
      #=> {:ok, %LLMDB.Model{provider: :anthropic, id: "claude-3-sonnet"}}

  """
  @spec model(String.t() | {atom(), String.t(), keyword()} | {atom(), keyword()} | struct()) ::
          {:ok, LLMDB.Model.t()} | {:error, term()}
  def model(%LLMDB.Model{} = model), do: {:ok, model}

  def model({provider, model_id, _opts}) when is_atom(provider) and is_binary(model_id) do
    ModelResolver.resolve("#{provider}:#{model_id}")
  end

  def model({provider, kw}) when is_atom(provider) and is_list(kw) do
    case kw[:id] || kw[:model] do
      id when is_binary(id) -> ModelResolver.resolve("#{provider}:#{id}")
      _ -> {:error, {:invalid_model_spec, kw}}
    end
  end

  def model(spec) when is_binary(spec) do
    ModelResolver.resolve(spec)
  end

  def model(other) do
    {:error, {:invalid_model_spec, other}}
  end

  # ===========================================================================
  # Tool API
  # ===========================================================================

  @doc """
  Creates a Tool struct from the given options.

  This is a convenience wrapper around `ReqLlmNext.Tool.new!/1`.

  ## Options

    * `:name` - Tool name (required, must be valid identifier)
    * `:description` - Tool description for AI model (required)
    * `:parameter_schema` - Parameter schema as NimbleOptions keyword list (optional)
    * `:callback` - Callback function or MFA tuple (required)

  ## Examples

      tool = ReqLlmNext.tool(
        name: "get_weather",
        description: "Get current weather for a location",
        parameter_schema: [
          location: [type: :string, required: true, doc: "City name"],
          units: [type: :string, default: "metric", doc: "Temperature units"]
        ],
        callback: {WeatherAPI, :fetch_weather}
      )

  """
  @spec tool(keyword()) :: Tool.t()
  def tool(opts) when is_list(opts) do
    Tool.new!(opts)
  end

  # ===========================================================================
  # Embeddings API
  # ===========================================================================

  @type model_spec :: String.t() | {atom(), String.t(), keyword()} | LLMDB.Model.t()

  @doc """
  Generate embeddings for text input(s).

  ## Parameters

    * `model_spec` - Embedding model specification (e.g., "openai:text-embedding-3-small")
    * `input` - Single text string or list of strings
    * `opts` - Additional options

  ## Options

    * `:dimensions` - Output vector dimensions (for models that support it)
    * `:encoding_format` - "float" (default) or "base64"

  ## Examples

      # Single text
      {:ok, embedding} = ReqLlmNext.embed("openai:text-embedding-3-small", "Hello world")

      # Multiple texts
      {:ok, embeddings} = ReqLlmNext.embed("openai:text-embedding-3-small", ["Hello", "World"])

  """
  @spec embed(model_spec(), String.t() | [String.t()], keyword()) ::
          {:ok, [float()] | [[float()]]} | {:error, term()}
  def embed(model_spec, input, opts \\ []) do
    Executor.embed(model_spec, input, opts)
  end

  @doc """
  Generate embeddings for text input(s).

  Bang version that raises on error.

  ## Examples

      embedding = ReqLlmNext.embed!("openai:text-embedding-3-small", "Hello world")

  """
  @spec embed!(model_spec(), String.t() | [String.t()], keyword()) :: [float()] | [[float()]]
  def embed!(model_spec, input, opts \\ []) do
    case embed(model_spec, input, opts) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Compute cosine similarity between two vectors.

  Returns a value between -1 and 1, where:
  - 1 means identical direction
  - 0 means orthogonal (perpendicular)
  - -1 means opposite direction

  ## Examples

      vec1 = [1.0, 0.0, 0.0]
      vec2 = [1.0, 0.0, 0.0]
      ReqLlmNext.cosine_similarity(vec1, vec2)
      #=> 1.0

      vec1 = [1.0, 0.0]
      vec2 = [0.0, 1.0]
      ReqLlmNext.cosine_similarity(vec1, vec2)
      #=> 0.0

  """
  @spec cosine_similarity([float()], [float()]) :: float()
  def cosine_similarity(vec1, vec2) when is_list(vec1) and is_list(vec2) do
    dot_product = Enum.zip(vec1, vec2) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
    magnitude1 = :math.sqrt(Enum.reduce(vec1, 0.0, fn x, acc -> acc + x * x end))
    magnitude2 = :math.sqrt(Enum.reduce(vec2, 0.0, fn x, acc -> acc + x * x end))

    if magnitude1 == 0.0 or magnitude2 == 0.0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end

  @doc """
  Returns list of supported embedding model specifications.

  ## Examples

      ReqLlmNext.embedding_models()
      #=> ["openai:text-embedding-3-small", "openai:text-embedding-3-large", ...]

  """
  @spec embedding_models() :: [String.t()]
  def embedding_models do
    Providers.list()
    |> Enum.flat_map(fn provider ->
      LLMDB.models(provider)
      |> Enum.filter(fn model ->
        model.capabilities && is_map(model.capabilities[:embeddings])
      end)
      |> Enum.map(fn model ->
        LLMDB.Model.spec(model)
      end)
    end)
  end

  # ===========================================================================
  # Schema API
  # ===========================================================================

  @doc """
  Build a JSON Schema from a NimbleOptions specification.

  Converts a NimbleOptions keyword list schema to JSON Schema format suitable
  for use with LLM structured output features.

  ## Options

    * `:name` - Schema name/title (optional)
    * `:description` - Schema description (optional)

  ## Examples

      schema = [
        name: [type: :string, required: true, doc: "User's name"],
        age: [type: :integer, required: true]
      ]

      json_schema = ReqLlmNext.json_schema(schema, name: "User")
      #=> %{
      #     "type" => "object",
      #     "title" => "User",
      #     "properties" => %{
      #       "name" => %{"type" => "string", "description" => "User's name"},
      #       "age" => %{"type" => "integer"}
      #     },
      #     "required" => ["name", "age"],
      #     "additionalProperties" => false
      #   }

  """
  @spec json_schema(keyword(), keyword()) :: map()
  def json_schema(nimble_schema, opts \\ []) do
    Schema.from_nimble(nimble_schema, opts)
  end
end
