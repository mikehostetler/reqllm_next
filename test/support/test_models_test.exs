defmodule ReqLlmNext.TestModelsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.TestModels

  describe "openai/1" do
    test "creates OpenAI model with defaults" do
      model = TestModels.openai()
      assert model.provider == :openai
      assert model.id == "test-model"
      assert model.capabilities.chat == true
    end

    test "applies overrides" do
      model = TestModels.openai(%{id: "custom-model", name: "Custom"})
      assert model.id == "custom-model"
      assert model.name == "Custom"
    end
  end

  describe "anthropic/1" do
    test "creates Anthropic model with defaults" do
      model = TestModels.anthropic()
      assert model.provider == :anthropic
      assert model.id == "test-model"
    end

    test "applies overrides" do
      model = TestModels.anthropic(%{id: "claude-custom"})
      assert model.id == "claude-custom"
    end
  end

  describe "google/1" do
    test "creates Google model with defaults" do
      model = TestModels.google()
      assert model.provider == :google
      assert model.id == "test-model"
    end

    test "applies overrides" do
      model = TestModels.google(%{id: "gemini-custom"})
      assert model.id == "gemini-custom"
    end
  end

  describe "openai_reasoning/1" do
    test "creates reasoning model with wire protocol" do
      model = TestModels.openai_reasoning()
      assert model.provider == :openai
      assert model.id == "o1-test"
      assert model.capabilities.reasoning.enabled == true
      assert model.extra.wire.protocol == :openai_responses
    end

    test "applies overrides" do
      model = TestModels.openai_reasoning(%{id: "o3-test"})
      assert model.id == "o3-test"
    end
  end

  describe "anthropic_thinking/1" do
    test "creates thinking model" do
      model = TestModels.anthropic_thinking()
      assert model.provider == :anthropic
      assert model.capabilities.reasoning.enabled == true
    end

    test "applies overrides" do
      model = TestModels.anthropic_thinking(%{id: "custom-thinking"})
      assert model.id == "custom-thinking"
    end
  end

  describe "openai_embedding/1" do
    test "creates embedding model" do
      model = TestModels.openai_embedding()
      assert model.provider == :openai
      assert model.capabilities.embeddings != false
      assert model.capabilities.chat == false
    end

    test "applies overrides" do
      model = TestModels.openai_embedding(%{id: "ada-custom"})
      assert model.id == "ada-custom"
    end
  end

  describe "vision/1" do
    test "creates vision model with image modality" do
      model = TestModels.vision()
      assert :image in model.modalities.input
    end

    test "applies overrides" do
      model = TestModels.vision(%{id: "vision-custom"})
      assert model.id == "vision-custom"
    end
  end

  describe "openrouter/1" do
    test "creates OpenRouter model" do
      model = TestModels.openrouter()
      assert model.provider == :openrouter
    end

    test "applies overrides" do
      model = TestModels.openrouter(%{id: "custom-router"})
      assert model.id == "custom-router"
    end
  end

  describe "groq/1" do
    test "creates Groq model" do
      model = TestModels.groq()
      assert model.provider == :groq
    end

    test "applies overrides" do
      model = TestModels.groq(%{id: "llama-custom"})
      assert model.id == "llama-custom"
    end
  end

  describe "xai/1" do
    test "creates xAI model" do
      model = TestModels.xai()
      assert model.provider == :xai
    end

    test "applies overrides" do
      model = TestModels.xai(%{id: "grok-custom"})
      assert model.id == "grok-custom"
    end
  end

  describe "minimal/1" do
    test "creates minimal model with only required fields" do
      model = TestModels.minimal()
      assert model.provider == :test
      assert model.id == "minimal-test"
    end

    test "applies overrides" do
      model = TestModels.minimal(%{provider: :custom, id: "minimal-custom"})
      assert model.provider == :custom
      assert model.id == "minimal-custom"
    end
  end

  describe "spec functions" do
    test "openai_spec returns correct string" do
      assert TestModels.openai_spec() == "openai:test-model"
    end

    test "anthropic_spec returns correct string" do
      assert TestModels.anthropic_spec() == "anthropic:test-model"
    end

    test "google_spec returns correct string" do
      assert TestModels.google_spec() == "google:test-model"
    end

    test "embedding_spec returns correct string" do
      assert TestModels.embedding_spec() == "openai:text-embedding-test"
    end
  end
end
