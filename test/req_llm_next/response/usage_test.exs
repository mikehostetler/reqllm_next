defmodule ReqLlmNext.Response.UsageTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Response.Usage

  @model %LLMDB.Model{id: "gpt-4o", provider: :openai}

  describe "normalize/2" do
    test "returns nil for nil input" do
      assert Usage.normalize(nil, @model) == nil
    end

    test "returns nil for empty map" do
      assert Usage.normalize(%{}, @model) == nil
    end

    test "normalizes OpenAI usage format" do
      raw = %{
        "prompt_tokens" => 12,
        "completion_tokens" => 8,
        "total_tokens" => 20
      }

      result = Usage.normalize(raw, @model)

      assert result.input_tokens == 12
      assert result.output_tokens == 8
      assert result.total_tokens == 20
    end

    test "extracts reasoning tokens from OpenAI" do
      raw = %{
        "prompt_tokens" => 12,
        "completion_tokens" => 72,
        "total_tokens" => 84,
        "completion_tokens_details" => %{
          "reasoning_tokens" => 64
        }
      }

      result = Usage.normalize(raw, @model)

      assert result.input_tokens == 12
      assert result.output_tokens == 72
      assert result.total_tokens == 84
      assert result.reasoning_tokens == 64
    end

    test "extracts cached tokens from OpenAI" do
      raw = %{
        "prompt_tokens" => 100,
        "completion_tokens" => 50,
        "total_tokens" => 150,
        "prompt_tokens_details" => %{
          "cached_tokens" => 80
        }
      }

      result = Usage.normalize(raw, @model)

      assert result.input_tokens == 100
      assert result.output_tokens == 50
      assert result.cache_read_tokens == 80
    end

    test "normalizes Anthropic usage format" do
      anthropic_model = %LLMDB.Model{id: "claude-3-sonnet", provider: :anthropic}

      raw = %{
        "input_tokens" => 15,
        "output_tokens" => 25
      }

      result = Usage.normalize(raw, anthropic_model)

      assert result.input_tokens == 15
      assert result.output_tokens == 25
      assert result.total_tokens == 40
    end

    test "extracts cache tokens from Anthropic" do
      anthropic_model = %LLMDB.Model{id: "claude-3-sonnet", provider: :anthropic}

      raw = %{
        "input_tokens" => 15,
        "output_tokens" => 25,
        "cache_read_input_tokens" => 10,
        "cache_creation_input_tokens" => 5
      }

      result = Usage.normalize(raw, anthropic_model)

      assert result.input_tokens == 15
      assert result.output_tokens == 25
      assert result.cache_read_tokens == 10
      assert result.cache_creation_tokens == 5
    end

    test "handles atom keys" do
      raw = %{
        prompt_tokens: 12,
        completion_tokens: 8,
        total_tokens: 20
      }

      result = Usage.normalize(raw, @model)

      assert result.input_tokens == 12
      assert result.output_tokens == 8
      assert result.total_tokens == 20
    end

    test "calculates total_tokens when not provided" do
      raw = %{
        "prompt_tokens" => 10,
        "completion_tokens" => 5
      }

      result = Usage.normalize(raw, @model)

      assert result.total_tokens == 15
    end

    test "handles Anthropic format with reasoning-like tokens" do
      raw = %{
        "input_tokens" => 20,
        "output_tokens" => 30
      }

      result = Usage.normalize(raw, @model)

      assert result.input_tokens == 20
      assert result.output_tokens == 30
      assert result.total_tokens == 50
    end

    test "extracts reasoning tokens from generic format" do
      raw = %{
        "prompt_tokens" => 20,
        "completion_tokens" => 30,
        "reasoning_tokens" => 10
      }

      result = Usage.normalize(raw, @model)

      assert result.input_tokens == 20
      assert result.output_tokens == 30
      assert result.reasoning_tokens == 10
    end
  end
end
