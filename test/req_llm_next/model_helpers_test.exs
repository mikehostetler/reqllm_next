defmodule ReqLlmNext.ModelHelpersTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.ModelHelpers
  alias ReqLlmNext.TestModels

  describe "reasoning_enabled?/1" do
    test "returns true when reasoning is enabled" do
      model = TestModels.openai_reasoning()
      assert ModelHelpers.reasoning_enabled?(model)
    end

    test "returns false when reasoning is disabled" do
      model = TestModels.openai()
      refute ModelHelpers.reasoning_enabled?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.reasoning_enabled?(nil)
      refute ModelHelpers.reasoning_enabled?("string")
      refute ModelHelpers.reasoning_enabled?(%{})
    end
  end

  describe "json_native?/1" do
    test "returns true when json native is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.json_native?(model)
    end

    test "returns false when json native is disabled" do
      model = TestModels.openai(%{capabilities: %{json: %{native: false}}})
      refute ModelHelpers.json_native?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.json_native?(nil)
      refute ModelHelpers.json_native?(%{capabilities: %{json: %{native: true}}})
    end
  end

  describe "json_schema?/1" do
    test "returns true when json schema is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.json_schema?(model)
    end

    test "returns false when json schema is disabled" do
      model = TestModels.anthropic()
      refute ModelHelpers.json_schema?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.json_schema?(nil)
    end
  end

  describe "json_strict?/1" do
    test "returns true when json strict is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.json_strict?(model)
    end

    test "returns false when json strict is disabled" do
      model = TestModels.anthropic()
      refute ModelHelpers.json_strict?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.json_strict?(nil)
    end
  end

  describe "tools_enabled?/1" do
    test "returns true when tools are enabled" do
      model = TestModels.openai()
      assert ModelHelpers.tools_enabled?(model)
    end

    test "returns false when tools are disabled" do
      model = TestModels.openai_reasoning()
      refute ModelHelpers.tools_enabled?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.tools_enabled?(nil)
    end
  end

  describe "tools_strict?/1" do
    test "returns true when tools strict is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.tools_strict?(model)
    end

    test "returns false when tools strict is disabled" do
      model = TestModels.anthropic()
      refute ModelHelpers.tools_strict?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.tools_strict?(nil)
    end
  end

  describe "tools_parallel?/1" do
    test "returns true when tools parallel is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.tools_parallel?(model)
    end

    test "returns false when tools parallel is disabled" do
      model = TestModels.google()
      refute ModelHelpers.tools_parallel?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.tools_parallel?(nil)
    end
  end

  describe "tools_streaming?/1" do
    test "returns true when tools streaming is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.tools_streaming?(model)
    end

    test "returns false when tools streaming is disabled" do
      model = TestModels.openai_reasoning()
      refute ModelHelpers.tools_streaming?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.tools_streaming?(nil)
    end
  end

  describe "streaming_text?/1" do
    test "returns true when text streaming is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.streaming_text?(model)
    end

    test "returns false when text streaming is disabled" do
      model = TestModels.openai_embedding()
      refute ModelHelpers.streaming_text?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.streaming_text?(nil)
    end
  end

  describe "streaming_tool_calls?/1" do
    test "returns true when tool call streaming is enabled" do
      model = TestModels.openai()
      assert ModelHelpers.streaming_tool_calls?(model)
    end

    test "returns false when tool call streaming is disabled" do
      model = TestModels.openai_reasoning()
      refute ModelHelpers.streaming_tool_calls?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.streaming_tool_calls?(nil)
    end
  end

  describe "chat?/1" do
    test "returns true for chat model" do
      model = TestModels.openai()
      assert ModelHelpers.chat?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute ModelHelpers.chat?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.chat?(nil)
    end
  end

  describe "embeddings?/1" do
    test "returns false for chat model" do
      model = TestModels.openai()
      refute ModelHelpers.embeddings?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.embeddings?(nil)
    end
  end

  describe "supports_object_generation?/1" do
    test "returns true when model supports json schema" do
      model = TestModels.openai()
      assert ModelHelpers.supports_object_generation?(model)
    end

    test "returns false when model does not support json schema" do
      model = TestModels.anthropic()
      refute ModelHelpers.supports_object_generation?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.supports_object_generation?(nil)
      refute ModelHelpers.supports_object_generation?("string")
      refute ModelHelpers.supports_object_generation?(%{})
    end
  end

  describe "supports_streaming_object_generation?/1" do
    test "returns true when model supports object generation and streaming" do
      model = TestModels.openai()
      assert ModelHelpers.supports_streaming_object_generation?(model)
    end

    test "returns false when model does not support json schema" do
      model = TestModels.anthropic()
      refute ModelHelpers.supports_streaming_object_generation?(model)
    end

    test "returns false when streaming tool calls is explicitly false" do
      model =
        TestModels.openai(%{
          capabilities: %{json: %{schema: true}, streaming: %{tool_calls: false}}
        })

      refute ModelHelpers.supports_streaming_object_generation?(model)
    end

    test "returns true when streaming tool calls is nil (not set)" do
      model =
        TestModels.openai(%{capabilities: %{json: %{schema: true}, streaming: %{text: true}}})

      assert ModelHelpers.supports_streaming_object_generation?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.supports_streaming_object_generation?(nil)
      refute ModelHelpers.supports_streaming_object_generation?("string")
      refute ModelHelpers.supports_streaming_object_generation?(%{})
    end
  end

  describe "supports_image_input?/1" do
    test "returns true when model supports image input" do
      model = TestModels.vision()
      assert ModelHelpers.supports_image_input?(model)
    end

    test "returns false when model does not support image input" do
      model = TestModels.openai()
      refute ModelHelpers.supports_image_input?(model)
    end

    test "returns false for non-chat models even with image modality" do
      model =
        TestModels.openai_embedding(%{
          modalities: %{input: [:text, :image], output: [:embedding]}
        })

      refute ModelHelpers.supports_image_input?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.supports_image_input?(nil)
      refute ModelHelpers.supports_image_input?("string")
    end
  end

  describe "supports_audio_input?/1" do
    test "returns true when model supports audio input" do
      model = TestModels.openai(%{modalities: %{input: [:text, :audio], output: [:text]}})
      assert ModelHelpers.supports_audio_input?(model)
    end

    test "returns false when model does not support audio input" do
      model = TestModels.openai()
      refute ModelHelpers.supports_audio_input?(model)
    end

    test "returns false for non-chat models" do
      model = TestModels.openai_embedding()
      refute ModelHelpers.supports_audio_input?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.supports_audio_input?(nil)
      refute ModelHelpers.supports_audio_input?("string")
    end
  end

  describe "supports_pdf_input?/1" do
    test "returns true when model supports pdf input" do
      model = TestModels.openai(%{modalities: %{input: [:text, :pdf], output: [:text]}})
      assert ModelHelpers.supports_pdf_input?(model)
    end

    test "returns false when model does not support pdf input" do
      model = TestModels.openai()
      refute ModelHelpers.supports_pdf_input?(model)
    end

    test "returns false for non-chat models" do
      model = TestModels.openai_embedding()
      refute ModelHelpers.supports_pdf_input?(model)
    end

    test "returns false for non-model values" do
      refute ModelHelpers.supports_pdf_input?(nil)
      refute ModelHelpers.supports_pdf_input?("string")
    end
  end

  describe "list_helpers/0" do
    test "returns a list of capability check function names" do
      helpers = ModelHelpers.list_helpers()

      assert is_list(helpers)
      assert :reasoning_enabled? in helpers
      assert :json_native? in helpers
      assert :tools_enabled? in helpers
      assert :chat? in helpers
      assert :embeddings? in helpers
    end

    test "returns a sorted list" do
      helpers = ModelHelpers.list_helpers()
      assert helpers == Enum.sort(helpers)
    end

    test "contains all 12 capability checks" do
      helpers = ModelHelpers.list_helpers()
      assert length(helpers) == 12
    end
  end
end
