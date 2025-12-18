defmodule ReqLlmNext.TestModels do
  @moduledoc """
  Factory functions for creating test model structs.

  These functions create `%LLMDB.Model{}` structs with sensible defaults
  for testing, without depending on specific model IDs from the live LLMDB
  catalog which may change over time.

  ## Usage

      # In tests, use these instead of hard-coded model specs:
      model = TestModels.openai()           # Generic OpenAI chat model
      model = TestModels.anthropic()        # Generic Anthropic model
      model = TestModels.openai_reasoning() # OpenAI o-series model
      model = TestModels.embedding()        # Embedding model

      # For model spec strings in integration tests:
      TestModels.openai_spec()      #=> "openai:test-model"
      TestModels.anthropic_spec()   #=> "anthropic:test-model"

  ## Guidelines

  - Unit tests should use these factory functions, not real LLMDB lookups
  - Coverage/integration tests that hit real APIs should use real model specs
  - When testing provider-specific behavior, use the appropriate factory
  """

  @doc """
  Creates a generic OpenAI chat model for testing.
  """
  def openai(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "test-model",
      provider: :openai,
      name: "Test Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: true, parallel: true},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 128_000, output: 16_384},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a generic Anthropic model for testing.
  """
  def anthropic(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "test-model",
      provider: :anthropic,
      name: "Test Claude Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 200_000, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a Google/Gemini model for testing.
  """
  def google(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "test-model",
      provider: :google,
      name: "Test Gemini Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: false},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 1_000_000, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an OpenAI reasoning model (o-series) for testing.

  Includes `extra.wire.protocol: :openai_responses` and `extra.api: "responses"`
  to match real reasoning model metadata.
  """
  def openai_reasoning(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "o1-test",
      provider: :openai,
      name: "Test O1 Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: true, token_budget: 25_000},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: true, tool_calls: false}
      },
      limits: %{context: 200_000, output: 100_000},
      modalities: %{input: [:text], output: [:text]},
      extra: %{
        wire: %{protocol: :openai_responses},
        api: "responses"
      }
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an Anthropic model with thinking/extended thinking capability.
  """
  def anthropic_thinking(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "claude-thinking-test",
      provider: :anthropic,
      name: "Test Claude Thinking Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: true, token_budget: 16_000},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 200_000, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an OpenAI embedding model for testing.
  """
  def openai_embedding(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "text-embedding-test",
      provider: :openai,
      name: "Test Embedding Model",
      capabilities: %{
        chat: false,
        embeddings: %{
          min_dimensions: 256,
          max_dimensions: 3072,
          default_dimensions: 1536
        },
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: false, tool_calls: false}
      },
      limits: %{context: 8_191, output: nil},
      modalities: %{input: [:text], output: [:embedding]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a model with vision capability.
  """
  def vision(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "vision-test",
      provider: :openai,
      name: "Test Vision Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: true, parallel: true},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 128_000, output: 16_384},
      modalities: %{input: [:text, :image], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an OpenRouter model for testing.
  """
  def openrouter(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "test-model",
      provider: :openrouter,
      name: "Test OpenRouter Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 128_000, output: 4_096},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a Groq model for testing.
  """
  def groq(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "test-model",
      provider: :groq,
      name: "Test Groq Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 131_072, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an xAI model for testing.
  """
  def xai(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "test-model",
      provider: :xai,
      name: "Test xAI Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 131_072, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a minimal model with only required fields.
  Useful for testing error cases or minimal behavior.
  """
  def minimal(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "minimal-test",
      provider: :test
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Returns a model spec string for OpenAI.
  Use only when you need a spec string (e.g., for API calls in tests with fixtures).
  """
  def openai_spec, do: "openai:test-model"

  @doc """
  Returns a model spec string for Anthropic.
  """
  def anthropic_spec, do: "anthropic:test-model"

  @doc """
  Returns a model spec string for Google.
  """
  def google_spec, do: "google:test-model"

  @doc """
  Returns a model spec string for an embedding model.
  """
  def embedding_spec, do: "openai:text-embedding-test"
end
