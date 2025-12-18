defmodule ReqLlmNext.ProvidersTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Provider
  alias ReqLlmNext.Providers
  alias ReqLlmNext.Providers.{Anthropic, OpenAI}

  describe "Providers.get/1" do
    test "returns OpenAI module for :openai" do
      assert Providers.get(:openai) == {:ok, OpenAI}
    end

    test "returns Anthropic module for :anthropic" do
      assert Providers.get(:anthropic) == {:ok, Anthropic}
    end

    test "returns error for unknown provider" do
      assert Providers.get(:unknown) == {:error, {:unknown_provider, :unknown}}
    end
  end

  describe "Providers.get!/1" do
    test "returns OpenAI module for :openai" do
      assert Providers.get!(:openai) == OpenAI
    end

    test "returns Anthropic module for :anthropic" do
      assert Providers.get!(:anthropic) == Anthropic
    end

    test "raises for unknown provider" do
      assert_raise RuntimeError, ~r/Provider error/, fn ->
        Providers.get!(:unknown)
      end
    end
  end

  describe "Providers.list/0" do
    test "returns list of supported providers" do
      providers = Providers.list()

      assert :openai in providers
      assert :anthropic in providers
    end
  end

  describe "Providers.OpenAI" do
    test "base_url returns OpenAI API URL" do
      assert OpenAI.base_url() == "https://api.openai.com/v1"
    end

    test "env_key returns OPENAI_API_KEY" do
      assert OpenAI.env_key() == "OPENAI_API_KEY"
    end

    test "auth_headers returns Bearer token" do
      headers = OpenAI.auth_headers("test-key")
      assert headers == [{"Authorization", "Bearer test-key"}]
    end
  end

  describe "Providers.Anthropic" do
    test "base_url returns Anthropic API URL" do
      assert Anthropic.base_url() == "https://api.anthropic.com"
    end

    test "env_key returns ANTHROPIC_API_KEY" do
      assert Anthropic.env_key() == "ANTHROPIC_API_KEY"
    end

    test "auth_headers returns x-api-key" do
      headers = Anthropic.auth_headers("test-key")

      assert {"x-api-key", "test-key"} in headers
    end

    test "headers includes auth and wire headers" do
      headers = Anthropic.headers("test-key")

      assert {"x-api-key", "test-key"} in headers
      assert {"anthropic-version", "2023-06-01"} in headers
    end

    test "headers includes beta flags when thinking enabled" do
      headers = Anthropic.headers("test-key", thinking: %{type: "enabled"})

      assert {"anthropic-beta", beta} = List.keyfind(headers, "anthropic-beta", 0)
      assert beta =~ "interleaved-thinking"
    end
  end

  describe "Provider.build_auth_headers/2" do
    test "builds bearer auth header" do
      headers = Provider.build_auth_headers(:bearer, "my-token")
      assert headers == [{"Authorization", "Bearer my-token"}]
    end

    test "builds x-api-key auth header" do
      headers = Provider.build_auth_headers(:x_api_key, "my-key")
      assert headers == [{"x-api-key", "my-key"}]
    end
  end

  describe "get_api_key/1" do
    test "OpenAI returns api_key from opts" do
      test_key = "test-key-openai"
      key = OpenAI.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "Anthropic returns api_key from opts" do
      test_key = "test-key-anthropic"
      key = Anthropic.get_api_key(api_key: test_key)
      assert key == test_key
    end

    test "OpenAI raises when no key available" do
      original = System.get_env("OPENAI_API_KEY")
      System.delete_env("OPENAI_API_KEY")

      try do
        assert_raise RuntimeError, ~r/OPENAI_API_KEY not set/, fn ->
          OpenAI.get_api_key([])
        end
      after
        if original, do: System.put_env("OPENAI_API_KEY", original)
      end
    end

    test "Anthropic raises when no key available" do
      original = System.get_env("ANTHROPIC_API_KEY")
      System.delete_env("ANTHROPIC_API_KEY")

      try do
        assert_raise RuntimeError, ~r/ANTHROPIC_API_KEY not set/, fn ->
          Anthropic.get_api_key([])
        end
      after
        if original, do: System.put_env("ANTHROPIC_API_KEY", original)
      end
    end
  end
end
