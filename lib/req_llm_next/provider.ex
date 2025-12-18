defmodule ReqLlmNext.Provider do
  @moduledoc """
  Behaviour for LLM provider implementations.

  Providers handle HTTP configuration (base URLs, auth headers, env keys)
  while Wire modules handle encoding/decoding of requests and responses.

  This separation allows:
  - One provider to support multiple wire formats (e.g., OpenAI Chat vs Responses)
  - Wire formats to be reused across providers (e.g., OpenAI-compatible APIs)
  """

  @type auth_header :: {String.t(), String.t()}

  @callback base_url() :: String.t()
  @callback env_key() :: String.t()
  @callback auth_headers(api_key :: String.t()) :: [auth_header()]

  @optional_callbacks []

  defmacro __using__(opts) do
    base_url = Keyword.fetch!(opts, :base_url)
    env_key = Keyword.fetch!(opts, :env_key)
    auth_style = Keyword.get(opts, :auth_style, :bearer)

    quote do
      @behaviour ReqLlmNext.Provider

      @impl ReqLlmNext.Provider
      def base_url, do: unquote(base_url)

      @impl ReqLlmNext.Provider
      def env_key, do: unquote(env_key)

      @impl ReqLlmNext.Provider
      def auth_headers(api_key) do
        ReqLlmNext.Provider.build_auth_headers(unquote(auth_style), api_key)
      end

      def get_api_key(opts) do
        Keyword.get(opts, :api_key) ||
          System.get_env(env_key()) ||
          raise "#{env_key()} not set"
      end

      defoverridable base_url: 0, env_key: 0, auth_headers: 1
    end
  end

  def build_auth_headers(:bearer, api_key) do
    [{"Authorization", "Bearer #{api_key}"}]
  end

  def build_auth_headers(:x_api_key, api_key) do
    [{"x-api-key", api_key}]
  end
end
