defmodule ReqLlmNext.Providers.Anthropic do
  @moduledoc """
  Anthropic provider configuration.

  ## Extended Thinking

  Anthropic Claude models support extended thinking, where the model shows
  its reasoning process. This is enabled via the adapter pipeline or
  directly through options.

  ## Prompt Caching

  Cache expensive system prompts and context for faster responses and
  reduced costs.

  See `ReqLlmNext.Wire.Anthropic` for wire protocol details.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.anthropic.com",
    env_key: "ANTHROPIC_API_KEY",
    auth_style: :x_api_key

  @impl ReqLlmNext.Provider
  def auth_headers(api_key) do
    [{"x-api-key", api_key}]
  end

  @doc """
  Build complete headers including auth and beta features.

  Called by Streaming.build_request to get all required headers.
  The wire module headers (including anthropic-version and beta flags)
  are added by the streaming module.
  """
  def headers(api_key, opts \\ []) do
    auth = auth_headers(api_key)
    wire_headers = ReqLlmNext.Wire.Anthropic.headers(opts)
    auth ++ wire_headers
  end
end
