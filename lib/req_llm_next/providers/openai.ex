defmodule ReqLlmNext.Providers.OpenAI do
  @moduledoc """
  OpenAI provider configuration.
  """

  use ReqLlmNext.Provider,
    base_url: "https://api.openai.com/v1",
    env_key: "OPENAI_API_KEY",
    auth_style: :bearer
end
