defmodule ReqLlmNext.Wire.AnthropicThinkingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Wire.Anthropic

  describe "headers/1" do
    test "returns base headers without beta flags when no special options" do
      headers = Anthropic.headers([])

      assert {"anthropic-version", "2023-06-01"} in headers
      assert {"content-type", "application/json"} in headers
      refute Enum.any?(headers, fn {k, _} -> k == "anthropic-beta" end)
    end

    test "includes thinking beta flag when thinking option present" do
      headers = Anthropic.headers(thinking: %{type: "enabled", budget_tokens: 4096})

      assert {"anthropic-beta", beta} = List.keyfind(headers, "anthropic-beta", 0)
      assert beta =~ "interleaved-thinking-2025-05-14"
    end

    test "includes thinking beta flag when reasoning_effort present" do
      headers = Anthropic.headers(reasoning_effort: :medium)

      assert {"anthropic-beta", beta} = List.keyfind(headers, "anthropic-beta", 0)
      assert beta =~ "interleaved-thinking-2025-05-14"
    end

    test "includes prompt caching beta flag" do
      headers = Anthropic.headers(anthropic_prompt_cache: true)

      assert {"anthropic-beta", beta} = List.keyfind(headers, "anthropic-beta", 0)
      assert beta =~ "prompt-caching-2024-07-31"
    end

    test "combines multiple beta flags" do
      headers = Anthropic.headers(thinking: %{type: "enabled"}, anthropic_prompt_cache: true)

      assert {"anthropic-beta", beta} = List.keyfind(headers, "anthropic-beta", 0)
      assert beta =~ "interleaved-thinking-2025-05-14"
      assert beta =~ "prompt-caching-2024-07-31"
    end
  end

  describe "map_reasoning_effort_to_budget/1" do
    test "maps :low to 1024" do
      assert Anthropic.map_reasoning_effort_to_budget(:low) == 1024
    end

    test "maps :medium to 2048" do
      assert Anthropic.map_reasoning_effort_to_budget(:medium) == 2048
    end

    test "maps :high to 4096" do
      assert Anthropic.map_reasoning_effort_to_budget(:high) == 4096
    end

    test "maps string values" do
      assert Anthropic.map_reasoning_effort_to_budget("low") == 1024
      assert Anthropic.map_reasoning_effort_to_budget("medium") == 2048
      assert Anthropic.map_reasoning_effort_to_budget("high") == 4096
    end

    test "defaults to medium for unknown values" do
      assert Anthropic.map_reasoning_effort_to_budget(:unknown) == 2048
    end
  end

  describe "encode_body/3 with thinking" do
    setup do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      {:ok, model: model}
    end

    test "adds thinking config when thinking option provided", %{model: model} do
      body =
        Anthropic.encode_body(model, "Hello!", thinking: %{type: "enabled", budget_tokens: 4096})

      assert body.thinking == %{type: "enabled", budget_tokens: 4096}
    end

    test "maps reasoning_effort to thinking config", %{model: model} do
      body = Anthropic.encode_body(model, "Hello!", reasoning_effort: :high)

      assert body.thinking == %{type: "enabled", budget_tokens: 4096}
    end

    test "supports all effort levels", %{model: model} do
      low = Anthropic.encode_body(model, "Hello!", reasoning_effort: :low)
      medium = Anthropic.encode_body(model, "Hello!", reasoning_effort: :medium)
      high = Anthropic.encode_body(model, "Hello!", reasoning_effort: :high)

      assert low.thinking == %{type: "enabled", budget_tokens: 1024}
      assert medium.thinking == %{type: "enabled", budget_tokens: 2048}
      assert high.thinking == %{type: "enabled", budget_tokens: 4096}
    end

    test "removes temperature when thinking enabled", %{model: model} do
      body =
        Anthropic.encode_body(model, "Hello!", thinking: %{type: "enabled"}, temperature: 0.7)

      refute Map.has_key?(body, :temperature)
    end

    test "preserves temperature when thinking not enabled", %{model: model} do
      body = Anthropic.encode_body(model, "Hello!", temperature: 0.7)

      assert body.temperature == 0.7
    end
  end

  describe "encode_body/3 with caching" do
    setup do
      model = %LLMDB.Model{id: "claude-sonnet-4-20250514", provider: :anthropic}
      {:ok, model: model}
    end

    test "adds cache_control to system content when caching enabled", %{model: model} do
      context = %ReqLlmNext.Context{
        messages: [
          %ReqLlmNext.Context.Message{
            role: :system,
            content: [%{type: :text, text: "You are helpful."}]
          },
          %ReqLlmNext.Context.Message{
            role: :user,
            content: [%{type: :text, text: "Hello!"}]
          }
        ]
      }

      body = Anthropic.encode_body(model, context, anthropic_prompt_cache: true)

      assert [%{type: "text", text: "You are helpful.", cache_control: cache_control}] =
               body.system

      assert cache_control == %{type: "ephemeral"}
    end

    test "supports custom TTL for cache", %{model: model} do
      context = %ReqLlmNext.Context{
        messages: [
          %ReqLlmNext.Context.Message{
            role: :system,
            content: [%{type: :text, text: "You are helpful."}]
          },
          %ReqLlmNext.Context.Message{
            role: :user,
            content: [%{type: :text, text: "Hello!"}]
          }
        ]
      }

      body =
        Anthropic.encode_body(model, context,
          anthropic_prompt_cache: true,
          anthropic_prompt_cache_ttl: 3600
        )

      assert [%{cache_control: %{type: "ephemeral", ttl: 3600}}] = body.system
    end

    test "keeps system as string when caching disabled", %{model: model} do
      context = %ReqLlmNext.Context{
        messages: [
          %ReqLlmNext.Context.Message{
            role: :system,
            content: [%{type: :text, text: "You are helpful."}]
          },
          %ReqLlmNext.Context.Message{
            role: :user,
            content: [%{type: :text, text: "Hello!"}]
          }
        ]
      }

      body = Anthropic.encode_body(model, context, [])

      assert body.system == "You are helpful."
    end
  end

  describe "decode_sse_event/2 thinking" do
    test "decodes thinking block start" do
      event = %{
        data: ~s({"type":"content_block_start","content_block":{"type":"thinking"}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert {:thinking_start, nil} in result
    end

    test "decodes thinking block start with initial text" do
      event = %{
        data:
          ~s({"type":"content_block_start","content_block":{"type":"thinking","thinking":"Let me think..."}}),
        event: nil,
        id: nil
      }

      result = Anthropic.decode_sse_event(event, nil)
      assert {:thinking_start, nil} in result
      assert {:thinking, "Let me think..."} in result
    end

    test "decodes thinking delta with thinking field" do
      event = %{
        data:
          ~s({"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"Step 1..."}}),
        event: nil,
        id: nil
      }

      assert [{:thinking, "Step 1..."}] = Anthropic.decode_sse_event(event, nil)
    end

    test "decodes thinking delta with text field" do
      event = %{
        data:
          ~s({"type":"content_block_delta","delta":{"type":"thinking_delta","text":"Step 2..."}}),
        event: nil,
        id: nil
      }

      assert [{:thinking, "Step 2..."}] = Anthropic.decode_sse_event(event, nil)
    end

    test "still decodes regular text deltas" do
      event = %{
        data: ~s({"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}),
        event: nil,
        id: nil
      }

      assert ["Hello"] = Anthropic.decode_sse_event(event, nil)
    end
  end

  describe "decode_sse_event/2 caching usage" do
    test "includes cache metrics in usage" do
      event = %{
        data:
          ~s({"type":"message_delta","usage":{"output_tokens":100,"cache_read_input_tokens":500,"cache_creation_input_tokens":200}}),
        event: nil,
        id: nil
      }

      [{:usage, usage}] = Anthropic.decode_sse_event(event, nil)

      assert usage.output_tokens == 100
      assert usage.cache_read_tokens == 500
      assert usage.cache_creation_tokens == 200
    end
  end
end
