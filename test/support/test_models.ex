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
  Creates a local Codex CLI model for testing.
  """
  def codex_cli(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "gpt-5-codex",
      provider: :codex_cli,
      name: "Test Codex CLI Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: false}
      },
      limits: %{context: 200_000, output: 32_768},
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
  Creates an OpenAI image-generation model for testing.
  """
  def openai_image(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "gpt-image-1",
      provider: :openai,
      name: "Test Image Model",
      family: "gpt-image",
      capabilities: %{
        chat: false,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: false, tool_calls: false}
      },
      modalities: %{input: [:text, :image], output: [:image]},
      extra: %{api: "images"}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an OpenAI transcription model for testing.
  """
  def openai_transcription(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "gpt-4o-transcribe",
      provider: :openai,
      name: "Test Transcription Model",
      capabilities: nil,
      modalities: nil
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an OpenAI speech model for testing.
  """
  def openai_speech(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "gpt-4o-mini-tts",
      provider: :openai,
      name: "Test Speech Model",
      capabilities: nil,
      modalities: nil
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an ElevenLabs speech model for testing.
  """
  def elevenlabs_speech(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "eleven_multilingual_v2",
      provider: :elevenlabs,
      name: "Test ElevenLabs Speech Model",
      capabilities: %{
        chat: false,
        embeddings: false,
        speech: true,
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: false, tool_calls: false}
      },
      modalities: %{input: [:text], output: [:audio]},
      extra: %{api: "text-to-speech"}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an ElevenLabs transcription model for testing.
  """
  def elevenlabs_transcription(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "scribe_v2",
      provider: :elevenlabs,
      name: "Test ElevenLabs Transcription Model",
      capabilities: %{
        chat: false,
        embeddings: false,
        transcription: true,
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: false, tool_calls: false}
      },
      modalities: %{input: [:audio], output: [:text]},
      extra: %{api: "speech-to-text"}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a Cohere chat model for testing.
  """
  def cohere(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "command-a-03-2025",
      provider: :cohere,
      name: "Test Cohere Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: true, schema: true, strict: false},
        streaming: %{text: true, tool_calls: false}
      },
      limits: %{context: 128_000, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
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
  Creates a Groq transcription model for testing.
  """
  def groq_transcription(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "whisper-large-v3-turbo",
      provider: :groq,
      name: "Test Groq Transcription Model",
      capabilities: %{
        chat: false,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: false, streaming: false, strict: false, parallel: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: true, tool_calls: false}
      },
      modalities: %{input: [:audio], output: [:text]},
      extra: %{
        api: "audio",
        supported_formats: ["mp3", "wav"]
      },
      tags: ["stt", "transcription"]
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a Venice model for testing.
  """
  def venice(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "venice-uncensored",
      provider: :venice,
      name: "Test Venice Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 128_000, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an Alibaba DashScope model for testing.
  """
  def alibaba(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "qwen-plus",
      provider: :alibaba,
      name: "Test Alibaba Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 131_072, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a Cerebras model for testing.
  """
  def cerebras(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "llama3.1-8b",
      provider: :cerebras,
      name: "Test Cerebras Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: true, parallel: false},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 131_072, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a Z.AI model for testing.
  """
  def zai(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "glm-4.6",
      provider: :zai,
      name: "Test Z.AI Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: true, token_budget: 32_000},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 131_072, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a Zenmux model for testing.
  """
  def zenmux(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "openai/gpt-5.2",
      provider: :zenmux,
      name: "Test Zenmux Model",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: true, token_budget: 32_000},
        tools: %{enabled: true, streaming: true, strict: true, parallel: true},
        json: %{native: true, schema: true, strict: true},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 200_000, output: 16_384},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates an xAI model for testing.
  """
  def xai(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "grok-4",
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
  Creates a legacy xAI model without native structured outputs.
  """
  def xai_legacy(overrides \\ %{}) do
    xai(%{id: "grok-2"} |> Map.merge(overrides))
  end

  @doc """
  Creates an xAI image-generation model for testing.
  """
  def xai_image(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "grok-imagine-1",
      provider: :xai,
      name: "Test xAI Image Model",
      family: "grok-imagine",
      capabilities: %{
        chat: false,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: false},
        json: %{native: false, schema: false, strict: false},
        streaming: %{text: false, tool_calls: false}
      },
      modalities: %{input: [:text, :image], output: [:image]},
      extra: %{api: "images"}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a vLLM model for testing.
  """
  def vllm(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "test-model",
      provider: :vllm,
      name: "Test vLLM Model",
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
  Creates a DeepSeek chat model for testing.
  """
  def deepseek(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "deepseek-chat",
      provider: :deepseek,
      name: "Test DeepSeek Chat",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: false},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 128_000, output: 8_192},
      modalities: %{input: [:text], output: [:text]}
    }

    struct!(base, Map.to_list(overrides))
  end

  @doc """
  Creates a DeepSeek reasoning model for testing.
  """
  def deepseek_reasoning(overrides \\ %{}) do
    base = %LLMDB.Model{
      id: "deepseek-reasoner",
      provider: :deepseek,
      name: "Test DeepSeek Reasoner",
      capabilities: %{
        chat: true,
        embeddings: false,
        reasoning: %{enabled: true, token_budget: 32_000},
        tools: %{enabled: true, streaming: true, strict: false, parallel: true},
        json: %{native: true, schema: false, strict: false},
        streaming: %{text: true, tool_calls: true}
      },
      limits: %{context: 128_000, output: 8_192},
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
  def elevenlabs_speech_spec, do: "elevenlabs:eleven_multilingual_v2"
  def elevenlabs_transcription_spec, do: "elevenlabs:scribe_v2"
  def cohere_spec, do: "cohere:command-a-03-2025"

  @doc """
  Returns a model spec string for an embedding model.
  """
  def embedding_spec, do: "openai:text-embedding-test"
end
