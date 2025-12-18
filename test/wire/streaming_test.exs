defmodule ReqLlmNext.Wire.StreamingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Providers.OpenAI
  alias ReqLlmNext.Wire.{OpenAIChat, Streaming}

  describe "build_request/5" do
    test "builds Finch request for OpenAI" do
      model = %LLMDB.Model{id: "gpt-4o-mini", provider: :openai}
      opts = [api_key: "test-key", max_tokens: 100]

      {:ok, request} = Streaming.build_request(OpenAI, OpenAIChat, model, "Hello!", opts)

      assert %Finch.Request{} = request
      assert request.method == "POST"
      assert request.host == "api.openai.com"
      assert request.path == "/v1/chat/completions"
    end

    test "includes auth headers" do
      model = %LLMDB.Model{id: "gpt-4o-mini", provider: :openai}
      opts = [api_key: "sk-test-key"]

      {:ok, request} = Streaming.build_request(OpenAI, OpenAIChat, model, "Hello!", opts)

      headers_map = Map.new(request.headers)
      assert headers_map["Authorization"] == "Bearer sk-test-key"
    end

    test "includes content-type and accept headers" do
      model = %LLMDB.Model{id: "gpt-4o-mini", provider: :openai}
      opts = [api_key: "test-key"]

      {:ok, request} = Streaming.build_request(OpenAI, OpenAIChat, model, "Hello!", opts)

      headers_map = Map.new(request.headers)
      assert headers_map["Content-Type"] == "application/json"
      assert headers_map["Accept"] == "text/event-stream"
    end

    test "encodes body as JSON" do
      model = %LLMDB.Model{id: "gpt-4o-mini", provider: :openai}
      opts = [api_key: "test-key", temperature: 0.5]

      {:ok, request} = Streaming.build_request(OpenAI, OpenAIChat, model, "Hello!", opts)

      body = Jason.decode!(request.body)
      assert body["model"] == "gpt-4o-mini"
      assert body["messages"] == [%{"role" => "user", "content" => "Hello!"}]
      assert body["stream"] == true
      assert body["temperature"] == 0.5
    end
  end

  describe "build_request/5 with Anthropic" do
    alias ReqLlmNext.Providers.Anthropic
    alias ReqLlmNext.Wire.Anthropic, as: AnthropicWire

    test "builds Finch request for Anthropic" do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      opts = [api_key: "test-key"]

      {:ok, request} = Streaming.build_request(Anthropic, AnthropicWire, model, "Hello!", opts)

      assert request.host == "api.anthropic.com"
      assert request.path == "/v1/messages"
    end

    test "includes anthropic auth headers" do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      opts = [api_key: "sk-ant-test"]

      {:ok, request} = Streaming.build_request(Anthropic, AnthropicWire, model, "Hello!", opts)

      headers_map = Map.new(request.headers)
      assert headers_map["x-api-key"] == "sk-ant-test"
      assert headers_map["anthropic-version"] == "2023-06-01"
    end
  end
end
