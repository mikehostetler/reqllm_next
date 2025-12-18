defmodule ReqLlmNext.ProviderTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Provider

  defmodule BearerProvider do
    use ReqLlmNext.Provider,
      base_url: "https://api.example.com/v1",
      env_key: "EXAMPLE_API_KEY",
      auth_style: :bearer
  end

  defmodule ApiKeyProvider do
    use ReqLlmNext.Provider,
      base_url: "https://api.other.com",
      env_key: "OTHER_API_KEY",
      auth_style: :x_api_key
  end

  defmodule CustomProvider do
    use ReqLlmNext.Provider,
      base_url: "https://default.example.com",
      env_key: "CUSTOM_API_KEY"

    @impl ReqLlmNext.Provider
    def base_url, do: "https://custom.example.com"

    @impl ReqLlmNext.Provider
    def auth_headers(api_key) do
      [{"Custom-Auth", "Token #{api_key}"}, {"X-Extra", "value"}]
    end

    @impl ReqLlmNext.Provider
    def get_api_key(opts) do
      Keyword.get(opts, :api_key, "default_key")
    end
  end

  describe "use Provider with :bearer auth_style" do
    test "base_url/0 returns configured URL" do
      assert BearerProvider.base_url() == "https://api.example.com/v1"
    end

    test "env_key/0 returns configured env key" do
      assert BearerProvider.env_key() == "EXAMPLE_API_KEY"
    end

    test "auth_headers/1 returns Bearer authorization header" do
      headers = BearerProvider.auth_headers("sk-test-key")
      assert headers == [{"Authorization", "Bearer sk-test-key"}]
    end

    test "get_api_key/1 returns key from opts" do
      key = BearerProvider.get_api_key(api_key: "from_opts")
      assert key == "from_opts"
    end

    test "get_api_key/1 falls back to env var" do
      System.put_env("EXAMPLE_API_KEY", "from_env")

      try do
        key = BearerProvider.get_api_key([])
        assert key == "from_env"
      after
        System.delete_env("EXAMPLE_API_KEY")
      end
    end

    test "get_api_key/1 raises when no key available" do
      System.delete_env("EXAMPLE_API_KEY")

      assert_raise RuntimeError, ~r/EXAMPLE_API_KEY not set/, fn ->
        BearerProvider.get_api_key([])
      end
    end
  end

  describe "use Provider with :x_api_key auth_style" do
    test "auth_headers/1 returns x-api-key header" do
      headers = ApiKeyProvider.auth_headers("my-secret-key")
      assert headers == [{"x-api-key", "my-secret-key"}]
    end
  end

  describe "overridable callbacks" do
    test "base_url can be overridden" do
      assert CustomProvider.base_url() == "https://custom.example.com"
    end

    test "auth_headers can be overridden" do
      headers = CustomProvider.auth_headers("custom-key")
      assert headers == [{"Custom-Auth", "Token custom-key"}, {"X-Extra", "value"}]
    end

    test "get_api_key can be overridden" do
      assert CustomProvider.get_api_key([]) == "default_key"
      assert CustomProvider.get_api_key(api_key: "override") == "override"
    end
  end

  describe "build_auth_headers/2" do
    test "builds bearer headers" do
      headers = Provider.build_auth_headers(:bearer, "test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end

    test "builds x_api_key headers" do
      headers = Provider.build_auth_headers(:x_api_key, "secret")
      assert headers == [{"x-api-key", "secret"}]
    end
  end

  describe "real providers" do
    test "OpenAI provider has correct configuration" do
      alias ReqLlmNext.Providers.OpenAI

      assert OpenAI.base_url() == "https://api.openai.com/v1"
      assert OpenAI.env_key() == "OPENAI_API_KEY"
      assert OpenAI.auth_headers("key") == [{"Authorization", "Bearer key"}]
    end

    test "Anthropic provider has correct configuration" do
      alias ReqLlmNext.Providers.Anthropic

      assert Anthropic.base_url() == "https://api.anthropic.com"
      assert Anthropic.env_key() == "ANTHROPIC_API_KEY"
      assert Anthropic.auth_headers("key") == [{"x-api-key", "key"}]
    end
  end
end
