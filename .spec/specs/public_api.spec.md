# Public API Contract

Current-truth contract for the top-level `ReqLlmNext` facade.

```spec-meta
id: reqllm.public_api
kind: api
status: active
summary: Hard package boundary for the top-level ReqLlmNext API, preserving the v1-style text, object, media, streaming, embedding, and helper surface while internals evolve.
surface:
  - lib/req_llm_next.ex
  - lib/req_llm_next/anthropic.ex
  - test/public_api/**/*.exs
```

## Requirements

```spec-requirements
- id: reqllm.public_api.hard_surface
  statement: `ReqLlmNext` shall expose the hard package boundary at the top-level facade with `generate_text/3`, `generate_text!/3`, `stream_text/3`, `stream_object/4`, `generate_object/4`, `generate_object!/4`, `generate_image/3`, `generate_image!/3`, `transcribe/3`, `transcribe!/3`, `speak/3`, `speak!/3`, `embed/3`, `embed!/3`, `support_status/1`, `model/1`, `provider/1`, `context/1`, `tool/1`, `json_schema/2`, `cosine_similarity/2`, `embedding_models/0`, `put_key/2`, and `get_key/1`, and the contract test lane shall load the facade module before asserting exported functions so the boundary check reflects the compiled public module rather than code-loading timing.
  priority: must
  stability: evolving

- id: reqllm.public_api.canonical_shapes
  statement: Top-level generation, media, and embedding entrypoints shall accept the canonical public model inputs of `LLMDB` `model_spec` strings or `%LLMDB.Model{}` values, including handcrafted local-provider models such as Codex CLI, return canonical `Response`, `StreamResponse`, `ReqLlmNext.Transcription.Result`, or `ReqLlmNext.Speech.Result` values from non-bang forms as appropriate, and raise from bang forms.
  priority: must
  stability: evolving

- id: reqllm.public_api.thin_facade
  statement: The top-level `ReqLlmNext` module shall remain a thin compatibility facade over the internal planning and execution pipeline rather than accumulating provider, protocol, wire, transport, fixture-specific, provider-utility, or provider-native helper branching logic.
  priority: must
  stability: evolving

- id: reqllm.public_api.provider_scoped_utilities
  statement: Provider-scoped public helper modules such as `ReqLlmNext.Anthropic` may expose explicit provider-native utility and helper surfaces outside the top-level facade, including Anthropic document helpers, provider-native tool helpers such as web search, web fetch, code execution, MCP, and computer use, file upload and download helpers, token counting, and message-batch lifecycle helpers such as create, get, list, cancel, delete, and results retrieval.
  priority: should
  stability: evolving

- id: reqllm.public_api.support_status
  statement: `ReqLlmNext.support_status/1` shall accept the same canonical model inputs as the execution facade and return `:first_class`, `:best_effort`, or `{:unsupported, reason}` based on integrated provider slices, typed `LLMDB` runtime and execution metadata, and explicit fail-fast unsupported reasons such as `:catalog_only`, `:missing_provider_runtime`, or `:missing_execution_metadata`, with first-class status reflecting actual provider-owned surfaces rather than provider registration alone so locally implemented Google embedding or image lanes and handcrafted Codex CLI models can report `:first_class` only when their provider-owned surfaces are real.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/public_api.spec.md
  covers:
    - reqllm.public_api.hard_surface
    - reqllm.public_api.canonical_shapes
    - reqllm.public_api.thin_facade
    - reqllm.public_api.provider_scoped_utilities
    - reqllm.public_api.support_status

- kind: command
  target: mix test test/public_api
  execute: true
  covers:
    - reqllm.public_api.hard_surface
    - reqllm.public_api.canonical_shapes
    - reqllm.public_api.support_status

- kind: command
  target: mix test test/providers/anthropic
  execute: true
  covers:
    - reqllm.public_api.provider_scoped_utilities
```
