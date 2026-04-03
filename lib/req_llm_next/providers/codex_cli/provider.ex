defmodule ReqLlmNext.Providers.CodexCLI do
  @moduledoc """
  Local Codex CLI provider configuration.
  """

  @behaviour ReqLlmNext.Provider

  @impl ReqLlmNext.Provider
  def base_url, do: "codex://local"

  @impl ReqLlmNext.Provider
  def env_key, do: "OPENAI_API_KEY"

  @impl ReqLlmNext.Provider
  def auth_headers(_api_key), do: []

  @impl ReqLlmNext.Provider
  def get_api_key(opts) do
    Keyword.get(opts, :api_key) || System.get_env(env_key()) || ""
  end
end
