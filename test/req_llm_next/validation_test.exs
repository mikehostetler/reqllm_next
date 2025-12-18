defmodule ReqLlmNext.ValidationTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Context.Message
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Validation

  describe "validate!/4 operation compatibility" do
    test "allows text operation on chat model" do
      model = TestModels.openai()
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "raises for text operation on embedding model" do
      model = TestModels.openai_embedding()
      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/cannot generate text/, fn ->
        Validation.validate!(model, :text, context, [])
      end
    end

    test "raises for object operation on embedding model" do
      model = TestModels.openai_embedding()
      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/cannot generate objects/, fn ->
        Validation.validate!(model, :object, context, [])
      end
    end

    test "raises for embed operation on chat model" do
      model = TestModels.openai()
      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/does not support embeddings/, fn ->
        Validation.validate!(model, :embed, context, [])
      end
    end

    test "allows embed operation on embedding model" do
      model = TestModels.openai_embedding()
      context = simple_context()

      assert :ok = Validation.validate!(model, :embed, context, [])
    end
  end

  describe "validate!/4 modalities" do
    test "allows text-only context on any model" do
      model = TestModels.openai()
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "raises for image content on non-vision model" do
      model = TestModels.openai()
      context = context_with_image()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/does not support image/, fn ->
        Validation.validate!(model, :text, context, [])
      end
    end

    test "allows image content on vision model" do
      model = TestModels.vision()
      context = context_with_image()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "allows image_url content on vision model" do
      model = TestModels.vision()
      context = context_with_image_url()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "allows nil context" do
      model = TestModels.openai()

      assert :ok = Validation.validate!(model, :text, nil, [])
    end
  end

  describe "validate!/4 capabilities" do
    test "allows tools on tool-capable model" do
      model = TestModels.openai()
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, tools: [%{}])
    end

    test "raises when tools requested but model doesn't support" do
      model = TestModels.openai(%{capabilities: %{tools: %{enabled: false}}})
      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/does not support tool/, fn ->
        Validation.validate!(model, :text, context, tools: [%{}])
      end
    end

    test "raises when streaming requested but model doesn't support" do
      model = TestModels.openai(%{capabilities: %{streaming: %{text: false}}})
      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/does not support streaming/, fn ->
        Validation.validate!(model, :text, context, stream: true)
      end
    end

    test "allows streaming on streaming-capable model" do
      model = TestModels.openai()
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, stream: true)
    end
  end

  describe "validate_stream!/3" do
    test "validates with string prompt" do
      model = TestModels.openai()

      assert :ok = Validation.validate_stream!(model, "Hello", [])
    end

    test "validates with Context" do
      model = TestModels.openai()
      context = simple_context()

      assert :ok = Validation.validate_stream!(model, context, [])
    end

    test "raises for image in context on non-vision model" do
      model = TestModels.openai()
      context = context_with_image()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/does not support image/, fn ->
        Validation.validate_stream!(model, context, [])
      end
    end

    test "validates with integer prompt (treated as nil context)" do
      model = TestModels.openai()

      assert :ok = Validation.validate_stream!(model, 123, [])
    end
  end

  describe "validate!/4 with nil capabilities" do
    test "uses default capabilities when model has nil capabilities" do
      model = TestModels.minimal(%{capabilities: nil})
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "allows tools with default capabilities" do
      model = TestModels.minimal(%{capabilities: nil})
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, tools: [%{}])
    end

    test "allows streaming with default capabilities" do
      model = TestModels.minimal(%{capabilities: nil})
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, stream: true)
    end
  end

  describe "validate!/4 object operation" do
    test "allows object operation on chat model" do
      model = TestModels.openai()
      context = simple_context()

      assert :ok = Validation.validate!(model, :object, context, [])
    end
  end

  describe "model kind inference" do
    test "infers reasoning kind from capabilities" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true},
            embeddings: false,
            tools: %{enabled: true},
            streaming: %{text: true}
          }
        })

      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "infers embedding kind from extra.type" do
      model =
        TestModels.openai(%{
          extra: %{type: "embedding"},
          capabilities: %{
            embeddings: %{default_dimensions: 1536}
          }
        })

      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/cannot generate text/, fn ->
        Validation.validate!(model, :text, context, [])
      end
    end

    test "infers embedding kind from embeddings capability" do
      model =
        TestModels.openai(%{
          capabilities: %{
            embeddings: %{default_dimensions: 1536},
            chat: false
          }
        })

      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/cannot generate text/, fn ->
        Validation.validate!(model, :text, context, [])
      end
    end

    test "infers chat kind as default" do
      model = TestModels.minimal()
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end
  end

  describe "modalities edge cases" do
    test "validates context with no images passes modality check" do
      model = TestModels.openai()

      context = %Context{
        messages: [
          %Message{
            role: :user,
            content: [ContentPart.text("Hello"), ContentPart.text("World")]
          }
        ]
      }

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "handles context with empty content list" do
      model = TestModels.openai()

      context = %Context{
        messages: [
          %Message{
            role: :user,
            content: []
          }
        ]
      }

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "handles context with nil content" do
      model = TestModels.openai()

      context = %Context{
        messages: [
          %Message{
            role: :user,
            content: nil
          }
        ]
      }

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "handles model with nil modalities" do
      model = TestModels.openai(%{modalities: nil})
      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end
  end

  describe "embeddings capability formats" do
    test "recognizes embeddings: true format" do
      model =
        TestModels.openai(%{
          capabilities: %{
            embeddings: true
          }
        })

      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/cannot generate text/, fn ->
        Validation.validate!(model, :text, context, [])
      end
    end

    test "recognizes embeddings map format" do
      model =
        TestModels.openai(%{
          capabilities: %{
            embeddings: %{min_dimensions: 256, max_dimensions: 3072}
          }
        })

      context = simple_context()

      assert_raise ReqLlmNext.Error.Invalid.Capability, ~r/cannot generate text/, fn ->
        Validation.validate!(model, :text, context, [])
      end
    end

    test "handles empty embeddings map as non-embedding" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            embeddings: %{},
            streaming: %{text: true},
            tools: %{enabled: true}
          }
        })

      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "handles embeddings: false as non-embedding" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            embeddings: false,
            streaming: %{text: true},
            tools: %{enabled: true}
          }
        })

      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end
  end

  describe "reasoning capability formats" do
    test "recognizes reasoning: true format" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            reasoning: true,
            embeddings: false,
            streaming: %{text: true},
            tools: %{enabled: true}
          }
        })

      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end

    test "recognizes reasoning map with enabled: true" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            reasoning: %{enabled: true, token_budget: 25000},
            embeddings: false,
            streaming: %{text: true},
            tools: %{enabled: true}
          }
        })

      context = simple_context()

      assert :ok = Validation.validate!(model, :text, context, [])
    end
  end

  defp simple_context do
    %Context{
      messages: [
        %Message{
          role: :user,
          content: [ContentPart.text("Hello")]
        }
      ]
    }
  end

  defp context_with_image do
    %Context{
      messages: [
        %Message{
          role: :user,
          content: [
            ContentPart.text("What is this?"),
            ContentPart.image(<<0, 1, 2, 3>>, "image/png")
          ]
        }
      ]
    }
  end

  defp context_with_image_url do
    %Context{
      messages: [
        %Message{
          role: :user,
          content: [
            ContentPart.text("What is this?"),
            ContentPart.image_url("https://example.com/image.png")
          ]
        }
      ]
    }
  end
end
