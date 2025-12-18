# AGENTS.md - ReqLlmNext v2

**IMPORTANT: DO NOT WRITE COMMENTS INTO THE BODY OF ANY FUNCTIONS.**

## Package Overview

`ReqLlmNext` is a metadata-driven LLM client library for Elixir. The architecture is designed so that, _ideally_, adding new models requires **only metadata updates in LLMDB**, not code changes. However, there are some models that require code changes to support (e.g. image input, audio input, PDF input, etc.). These are handled by the `adapters` layer.

## Core Design Principles

1. **LLMDB is the single source of truth** - Model capabilities, constraints, and wire protocol selection flow from LLMDB metadata
2. **Three-layer API client architecture** - Clear separation between Wire (encoding), Provider (HTTP), and Adapter (quirks)
3. **Scenarios as capability tests** - Model-agnostic test scenarios validate capabilities through the public API
4. **Streaming-first** - All operations internally use streaming; non-streaming calls buffer the stream

## Quick Start

```bash
# Run tests (uses fixture replay by default)
mix test

# Record new fixtures (live API calls)
REQ_LLM_NEXT_FIXTURES_MODE=record mix test

# Run specific scenario tests
mix test test/scenarios/

# Format and compile
mix format && mix compile
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ReqLlmNext Public API                           │
│  generate_text/3 · stream_text/3 · generate_object/4 · embed/3          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    ReqLlmNext.Executor (Central Pipeline)               │
│  1. ModelResolver    → LLMDB lookup + config overrides                  │
│  2. Validation       → Modalities, operation compatibility              │
│  3. Constraints      → Parameter transforms from LLMDB metadata         │
│  4. Adapter Pipeline → Per-model customizations (~5% of models)         │
│  5. Wire Protocol    → JSON encode/decode per API family                │
│  6. Provider HTTP    → Base URL, auth, Finch orchestration              │
└─────────────────────────────────────────────────────────────────────────┘
```

## Module Structure

```
lib/req_llm_next/
├── req_llm_next.ex              # Public API facade
├── executor.ex                   # Central pipeline orchestration
├── model_resolver.ex             # LLMDB + config overlays
│
├── validation.ex                 # Modality & operation checks
├── constraints.ex                # Parameter transforms from metadata
│
├── adapters/
│   ├── model_adapter.ex          # Behaviour definition
│   ├── pipeline.ex               # Adapter chain execution
│   ├── openai/
│   │   ├── reasoning.ex          # o-series, GPT-5 (Responses API)
│   │   └── gpt4o_mini.ex         # Model-specific defaults
│   └── anthropic/
│       └── thinking.ex           # Extended thinking mode
│
├── wire/
│   ├── streaming.ex              # Behaviour for streaming wires
│   ├── resolver.ex               # Select wire from model metadata
│   ├── openai_chat.ex            # /v1/chat/completions
│   ├── openai_responses.ex       # /v1/responses (reasoning)
│   ├── openai_embeddings.ex      # /v1/embeddings
│   └── anthropic.ex              # /v1/messages
│
├── providers/
│   ├── provider.ex               # Behaviour (base_url, auth)
│   ├── openai.ex                 # OpenAI config
│   └── anthropic.ex              # Anthropic config
│
├── scenarios/                    # Capability test scenarios
│   ├── basic.ex                  # Basic text generation
│   ├── streaming.ex              # SSE streaming
│   ├── tool_round_trip.ex        # Full tool execution flow
│   └── ...
│
├── context.ex                    # Conversation history
├── response.ex                   # Response struct + helpers
├── stream_response.ex            # Streaming response wrapper
├── tool.ex                       # Tool definition
├── tool_call.ex                  # Tool call struct
├── schema.ex                     # JSON Schema from NimbleOptions
├── fixtures.ex                   # Fixture record/replay system
└── error.ex                      # Structured errors (Splode)
```

## The Three-Layer API Client Design

### Layer 1: Wire Protocol

**Purpose**: Pure encoding/decoding between canonical ReqLlmNext types and provider JSON.

**Files**: `lib/req_llm_next/wire/*.ex`

**Behaviour** (`Wire.Streaming`):
```elixir
@callback endpoint() :: String.t()
@callback encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()
@callback decode_sse_event(sse_event(), LLMDB.Model.t()) :: [term()]
@callback headers(keyword()) :: [{String.t(), String.t()}]  # optional
```

**Decision criteria**: Add a new Wire module when:
- A provider uses a fundamentally different JSON structure
- SSE event format differs significantly
- Different endpoint paths or content types

**Current wires**:
- `Wire.OpenAIChat` - Standard OpenAI `/v1/chat/completions`
- `Wire.OpenAIResponses` - Reasoning models `/v1/responses`
- `Wire.Anthropic` - `/v1/messages` with thinking support
- `Wire.OpenAIEmbeddings` - `/v1/embeddings`

### Layer 2: Provider

**Purpose**: HTTP configuration only—base URLs, authentication headers, API keys.

**Files**: `lib/req_llm_next/providers/*.ex`

**Behaviour** (`Provider`):
```elixir
@callback base_url() :: String.t()
@callback env_key() :: String.t()
@callback auth_headers(api_key :: String.t()) :: [{String.t(), String.t()}]
```

**Decision criteria**: Add a new Provider module when:
- Different base URL
- Different authentication scheme
- Different API key environment variable

**Current providers**:
- `Providers.OpenAI` - Bearer auth, `OPENAI_API_KEY`
- `Providers.Anthropic` - x-api-key auth, `ANTHROPIC_API_KEY`

### Layer 3: Model Adapter (Optional)

**Purpose**: Per-model customizations for the ~5% of models that need special handling beyond what LLMDB metadata can express.

**Files**: `lib/req_llm_next/adapters/**/*.ex`

**Behaviour** (`ModelAdapter`):
```elixir
@callback matches?(LLMDB.Model.t()) :: boolean()
@callback transform_opts(LLMDB.Model.t(), keyword()) :: keyword()
```

**Decision criteria**: Add an Adapter when:
- Model requires parameters that can't be expressed in constraints
- Default values differ significantly from other models
- API quirks require field renaming or injection

**Current adapters**:
- `OpenAI.Reasoning` - Higher defaults, timeout, token key normalization
- `OpenAI.GPT4oMini` - Model-specific defaults
- `Anthropic.Thinking` - Extended thinking mode adjustments

## Constraints vs Adapters

**Constraints** (`constraints.ex`):
- Driven entirely by LLMDB `extra.constraints` metadata
- Generic parameter transformations applicable to any model
- Examples: token key renaming, temperature support, min output tokens

**Adapters** (`adapters/*.ex`):
- Per-model/family logic that can't be metadata-driven
- Applied after constraints in the pipeline
- Examples: injecting required fields, setting model-specific defaults

**Rule**: If a behavior can be expressed as LLMDB metadata, use Constraints. If it requires code logic, use an Adapter.

## Scenario System

Scenarios are the single source of truth for capability validation.

**Files**: `lib/req_llm_next/scenarios/*.ex`

**Behaviour** (`Scenario`):
```elixir
@callback applies?(LLMDB.Model.t()) :: boolean()
@callback run(model_spec :: String.t(), model :: LLMDB.Model.t(), opts :: keyword()) :: result()
```

**Usage**:
```elixir
# Get scenarios for a model
scenarios = ReqLlmNext.Scenarios.for_model(model)

# Run all applicable scenarios
results = ReqLlmNext.Scenarios.run_for_model("openai:gpt-4o-mini", model, opts)
```

**Fixture naming**: `fixture_name(scenario_id, step)` generates deterministic fixture paths.

## Fixture System

Fixtures capture raw SSE chunks for replay testing.

**Mode control**: `REQ_LLM_NEXT_FIXTURES_MODE=record|replay`

**Storage**: `test/fixtures/{provider}/{model_id}/{scenario}.json`

**Format**:
```json
{
  "provider": "openai",
  "model_id": "gpt-4o-mini",
  "prompt": "Hello!",
  "request": { "method": "POST", "url": "...", "headers": {...}, "body": {...} },
  "response": { "status": 200, "headers": {...} },
  "chunks": ["base64-encoded-sse-chunk", ...]
}
```

## Adding New Models

### If model uses existing wire protocol and provider:

1. Add model to LLMDB with correct metadata
2. Ensure `extra.wire.protocol` is set if not default
3. Run scenarios: `REQ_LLM_NEXT_FIXTURES_MODE=record mix test`
4. Commit fixtures

### If model needs new constraints:

1. Add constraint fields to LLMDB `extra.constraints`
2. If new constraint type, add handler to `Constraints` module

### If model needs adapter:

1. Create adapter in `lib/req_llm_next/adapters/{provider}/{name}.ex`
2. Register in `Adapters.Pipeline.@adapters`
3. Implement `matches?/1` and `transform_opts/2`

### If model uses new wire protocol:

1. Create wire module implementing `Wire.Streaming` behaviour
2. Add protocol atom to `Wire.Resolver.wire_module!/1`
3. Add LLMDB metadata: `extra.wire.protocol: "new_protocol"`

### If model uses new provider:

1. Create provider module using `use ReqLlmNext.Provider`
2. Register in `Providers.@providers`

## Code Style

- Follow standard Elixir conventions, run `mix format`
- No comments in function bodies
- Use pattern matching over conditionals
- Return `{:ok, result}` / `{:error, reason}` tuples
- Use Splode for structured errors

## Key Dependencies

- **LLMDB** - Model metadata database (separate package)
- **Finch** - HTTP client for streaming
- **Jason** - JSON encoding/decoding
- **ServerSentEvents** - SSE parsing
- **Zoi** - Struct schemas
- **Splode** - Error handling

## Environment Variables

- `OPENAI_API_KEY` - OpenAI API key
- `ANTHROPIC_API_KEY` - Anthropic API key
- `REQ_LLM_NEXT_FIXTURES_MODE` - `record` or `replay` (default: replay)
