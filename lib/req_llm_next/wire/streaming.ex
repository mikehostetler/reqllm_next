defmodule ReqLlmNext.Wire.Streaming do
  @moduledoc """
  Behaviour for streaming wire protocols.

  Wire protocols handle encoding requests and decoding SSE events.
  They are pure transformations - HTTP configuration (base URLs, auth)
  comes from Provider modules.
  """

  @type sse_event :: %{data: String.t(), event: String.t() | nil, id: String.t() | nil}

  @doc """
  Returns the endpoint path for this wire protocol.
  """
  @callback endpoint() :: String.t()

  @doc """
  Encodes a prompt into a request body map.
  """
  @callback encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()

  @doc """
  Decodes an SSE event into text chunks.
  Returns [nil] for terminal events, [] for non-content events.
  """
  @callback decode_sse_event(sse_event(), LLMDB.Model.t()) :: [String.t() | nil]

  @doc """
  Returns the options schema for this wire protocol.
  """
  @callback options_schema() :: keyword()

  @doc """
  Returns wire-specific headers for the request.

  Some wire protocols need custom headers based on options (e.g., Anthropic
  beta headers for thinking/caching features).
  """
  @callback headers(keyword()) :: [{String.t(), String.t()}]

  @optional_callbacks options_schema: 0, headers: 1

  @doc """
  Builds a complete Finch request using provider and wire protocol.
  """
  @spec build_request(module(), module(), LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, wire_mod, model, prompt, opts) do
    api_key = provider_mod.get_api_key(opts)
    base_url = Keyword.get(opts, :base_url, provider_mod.base_url())
    endpoint = wire_mod.endpoint()
    url = base_url <> endpoint

    auth_headers = provider_mod.auth_headers(api_key)
    wire_headers = get_wire_headers(wire_mod, opts)

    headers =
      auth_headers ++
        wire_headers ++
        [
          {"Accept", "text/event-stream"}
        ]

    body =
      wire_mod.encode_body(model, prompt, opts)
      |> Jason.encode!()

    {:ok, Finch.build(:post, url, headers, body)}
  end

  defp get_wire_headers(wire_mod, opts) do
    if function_exported?(wire_mod, :headers, 1) do
      wire_mod.headers(opts)
    else
      [{"Content-Type", "application/json"}]
    end
  end
end
