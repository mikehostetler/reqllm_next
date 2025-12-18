defmodule ReqLlmNext.ConstraintsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Constraints
  alias ReqLlmNext.TestModels

  describe "apply/2 token limit key" do
    test "renames max_tokens to max_completion_tokens when required" do
      model = reasoning_model()
      opts = [max_tokens: 1000, temperature: 0.7]

      result = Constraints.apply(model, opts)

      assert result[:max_completion_tokens] == 1000
      refute Keyword.has_key?(result, :max_tokens)
    end

    test "leaves max_tokens unchanged for chat models" do
      model = TestModels.openai()
      opts = [max_tokens: 1000]

      result = Constraints.apply(model, opts)

      assert result[:max_tokens] == 1000
      refute Keyword.has_key?(result, :max_completion_tokens)
    end

    test "does nothing when max_tokens not provided" do
      model = reasoning_model()
      opts = [temperature: 0.7]

      result = Constraints.apply(model, opts)

      assert result[:temperature] == 0.7
      refute Keyword.has_key?(result, :max_tokens)
      refute Keyword.has_key?(result, :max_completion_tokens)
    end
  end

  describe "apply/2 temperature constraint" do
    test "fixes temperature to 1.0 when required" do
      model = fixed_temp_model()
      opts = [temperature: 0.5]

      result = Constraints.apply(model, opts)

      assert result[:temperature] == 1.0
    end

    test "removes temperature when unsupported" do
      model = no_temp_model()
      opts = [temperature: 0.5, max_tokens: 100]

      result = Constraints.apply(model, opts)

      refute Keyword.has_key?(result, :temperature)
      assert result[:max_tokens] == 100
    end

    test "leaves temperature unchanged when any is allowed" do
      model = TestModels.openai()
      opts = [temperature: 0.5]

      result = Constraints.apply(model, opts)

      assert result[:temperature] == 0.5
    end
  end

  describe "apply/2 sampling constraint" do
    test "removes top_p and top_k when sampling unsupported" do
      model = no_sampling_model()
      opts = [top_p: 0.9, top_k: 50, max_tokens: 100]

      result = Constraints.apply(model, opts)

      refute Keyword.has_key?(result, :top_p)
      refute Keyword.has_key?(result, :top_k)
      assert result[:max_tokens] == 100
    end

    test "leaves sampling parameters when supported" do
      model = TestModels.openai()
      opts = [top_p: 0.9, top_k: 50]

      result = Constraints.apply(model, opts)

      assert result[:top_p] == 0.9
      assert result[:top_k] == 50
    end
  end

  describe "apply/2 min output tokens" do
    test "enforces minimum output tokens" do
      model = min_tokens_model()
      opts = [max_tokens: 500]

      result = Constraints.apply(model, opts)

      assert result[:max_tokens] == 1000
    end

    test "allows tokens above minimum" do
      model = min_tokens_model()
      opts = [max_tokens: 2000]

      result = Constraints.apply(model, opts)

      assert result[:max_tokens] == 2000
    end

    test "does nothing when max_tokens not specified" do
      model = min_tokens_model()
      opts = [temperature: 0.7]

      result = Constraints.apply(model, opts)

      assert result[:temperature] == 0.7
      refute Keyword.has_key?(result, :max_tokens)
    end

    test "enforces minimum on max_completion_tokens" do
      model = min_tokens_with_completion_key_model()
      opts = [max_tokens: 500]

      result = Constraints.apply(model, opts)

      assert result[:max_completion_tokens] == 1000
      refute Keyword.has_key?(result, :max_tokens)
    end
  end

  describe "apply/2 reasoning effort" do
    test "adds default reasoning_effort when required" do
      model = reasoning_required_model()
      opts = []

      result = Constraints.apply(model, opts)

      assert result[:reasoning_effort] == :medium
    end

    test "preserves explicit reasoning_effort when required" do
      model = reasoning_required_model()
      opts = [reasoning_effort: :high]

      result = Constraints.apply(model, opts)

      assert result[:reasoning_effort] == :high
    end

    test "removes reasoning_effort when unsupported" do
      model = no_reasoning_model()
      opts = [reasoning_effort: :high, max_tokens: 100]

      result = Constraints.apply(model, opts)

      refute Keyword.has_key?(result, :reasoning_effort)
      assert result[:max_tokens] == 100
    end

    test "leaves reasoning_effort when supported but not required" do
      model = reasoning_supported_model()
      opts = [reasoning_effort: :high]

      result = Constraints.apply(model, opts)

      assert result[:reasoning_effort] == :high
    end
  end

  describe "apply/2 combined constraints" do
    test "applies multiple constraints in order" do
      model =
        TestModels.openai_reasoning(%{
          extra: %{
            constraints: %{
              token_limit_key: :max_completion_tokens,
              temperature: :fixed_1,
              sampling: :unsupported,
              min_output_tokens: 1000,
              reasoning_effort: :required
            }
          }
        })

      opts = [
        max_tokens: 500,
        temperature: 0.5,
        top_p: 0.9,
        top_k: 50
      ]

      result = Constraints.apply(model, opts)

      assert result[:max_completion_tokens] == 1000
      assert result[:temperature] == 1.0
      assert result[:reasoning_effort] == :medium
      refute Keyword.has_key?(result, :max_tokens)
      refute Keyword.has_key?(result, :top_p)
      refute Keyword.has_key?(result, :top_k)
    end
  end

  defp reasoning_model do
    TestModels.openai_reasoning(%{
      extra: %{constraints: %{token_limit_key: :max_completion_tokens}}
    })
  end

  defp fixed_temp_model do
    TestModels.openai_reasoning(%{
      extra: %{constraints: %{temperature: :fixed_1}}
    })
  end

  defp no_temp_model do
    TestModels.openai(%{
      extra: %{constraints: %{temperature: :unsupported}}
    })
  end

  defp no_sampling_model do
    TestModels.openai_reasoning(%{
      extra: %{constraints: %{sampling: :unsupported}}
    })
  end

  defp min_tokens_model do
    TestModels.openai_reasoning(%{
      extra: %{constraints: %{min_output_tokens: 1000}}
    })
  end

  defp min_tokens_with_completion_key_model do
    TestModels.openai_reasoning(%{
      extra: %{
        constraints: %{
          token_limit_key: :max_completion_tokens,
          min_output_tokens: 1000
        }
      }
    })
  end

  defp reasoning_required_model do
    TestModels.openai_reasoning(%{
      extra: %{constraints: %{reasoning_effort: :required}}
    })
  end

  defp reasoning_supported_model do
    TestModels.openai_reasoning(%{
      extra: %{constraints: %{reasoning_effort: :supported}}
    })
  end

  defp no_reasoning_model do
    TestModels.openai(%{
      extra: %{constraints: %{reasoning_effort: :unsupported}}
    })
  end
end
