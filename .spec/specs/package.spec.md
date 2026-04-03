# Package Contract

High-level runtime contract for the ReqLlmNext library.

```spec-meta
id: reqllm.package
kind: package
status: active
summary: Metadata-driven LLM client runtime and test contract.
surface:
  - lib/**/*.ex
  - test/support/**/*.ex
  - test/**/*.exs
  - test/fixtures/**/*.json
decisions:
  - reqllm.decision.media_operation_families
  - reqllm.decision.canonical_output_items
  - reqllm.decision.transport_agnostic_realtime_core
  - reqllm.decision.runtime_telemetry_kernel
  - reqllm.decision.zoi_backed_struct_contracts
  - reqllm.decision.live_verifier_tests
  - reqllm.decision.llmdb_best_effort_runtime
  - reqllm.decision.loaded_optional_wire_callbacks
```

## Requirements

```spec-requirements
- id: reqllm.package.multi_provider_api
  statement: ReqLlmNext shall provide a unified public API for text generation, structured output, streaming, embeddings, and supported media operations across supported model providers using the same operations whether callers start from an `LLMDB` `model_spec` string or an `%LLMDB.Model{}`, including handcrafted structs used for local development and local first-class providers such as the Codex CLI spike, while distinguishing first-class integrated providers from best-effort packaged providers whose execution is driven by typed `LLMDB` runtime metadata.
  priority: must
  stability: evolving

- id: reqllm.package.fixture_replay
  statement: ReqLlmNext shall verify package behavior with deterministic automated tests that exercise provider scenarios and replay recorded fixtures by default, preserving the recorded execution surface when fixtures were captured against an older but still valid endpoint shape, including request-style fixtures for non-stream image, transcription, and speech operations plus line-framed local-process captures for CLI-backed surfaces such as Codex CLI, while keeping sparse live verifier tests as an explicit opt-in integration lane instead of broad live CI coverage.
  priority: must
  stability: evolving

- id: reqllm.package.execution_planning
  statement: ReqLlmNext shall route supported requests through a deterministic planning path that normalizes model facts into `ModelProfile`, request intent into `ExecutionMode`, selects explicit `ExecutionSurface` support through compatibility-aware policy, validates surface-specific parameter compatibility, materializes an `ExecutionPlan`, and resolves an execution stack of provider, session runtime, semantic protocol, wire, and transport modules before runtime execution, with provider facts, runtime-module lookup, and surface catalog construction driven from the compiled extension manifest for first-class providers and from typed `LLMDB.Provider.runtime` plus `LLMDB.Model.execution` metadata for best-effort providers rather than from central provider branching, and the runtime stack shall support HTTP, WebSocket, and provider-owned local-process transports such as the Codex CLI spike while keeping auth an external concern for those CLI-backed surfaces, while shared wire dispatch continues to honor provider-owned optional callbacks such as custom request builders and wire-specific headers even when those wire modules were not preloaded earlier in the VM lifetime.
  priority: must
  stability: evolving

- id: reqllm.package.buffered_stream_metadata
  statement: When ReqLlmNext buffers a streamed response into the canonical `Response` shape, it shall preserve terminal metadata such as finish reason and provider-facing response identifiers emitted by the canonical stream, and the same shared output-item materialization path shall drive explicit result-channel and helper extraction for streamed text, thinking, usage, transcripts, audio chunks, provider items, refusals, annotations, and tool calls so normalization stays consistent across buffered and streaming consumers.
  priority: should
  stability: evolving

- id: reqllm.package.model_slice_verification
  statement: ReqLlmNext shall be able to lock supported scenario sets to explicit starter-model slices and curated provider support-matrix lanes, including alternative transport lanes where relevant, so provider-specific support stays visible as the planning path evolves without exploding into a one-file-per-model matrix.
  priority: should
  stability: evolving

- id: reqllm.package.local_env_loading
  statement: ReqLlmNext shall support local development and replay or live verification by loading a local `.env` file without overriding shell-provided environment variables, so API keys can be supplied for tests and compatibility runs without being committed.
  priority: should
  stability: evolving

- id: reqllm.package.provider_specific_utilities
  statement: ReqLlmNext shall keep the top-level cross-provider facade narrow while exposing explicit provider-scoped utility modules for non-canonical provider endpoints such as Anthropic token counting, files, batches, and provider-native tool helpers including web search, web fetch, code execution, MCP, and computer use.
  priority: should
  stability: evolving

- id: reqllm.package.provider_native_input_isolation
  statement: ReqLlmNext shall keep canonical cross-provider tool input on `ReqLlmNext.Tool`, allow provider-native helper maps only on the owning provider surfaces, and fail early during planning when foreign raw maps or provider-native helper shapes are used on the wrong surface, including provider-native Responses helpers such as Anthropic-native tool helpers on Anthropic surfaces and xAI built-in tool helpers on xAI Responses surfaces.
  priority: must
  stability: evolving

- id: reqllm.package.compile_time_extensions
  statement: ReqLlmNext shall move provider and model edge-case support toward a compile-time extension manifest with provider registrations, explicit provider default families, global fallback families, family inheritance for reusing a happy-path stack, narrow opt-in override rules, manifest-backed provider facts and surface catalogs, built-in declaration packs discovered from co-located family and provider slice homes, session-runtime seams, realtime adapter seams, provider-local media family overrides where needed, and compile-time manifest verification so common paths stay simple while edge cases remain explicit, allowing providers such as DeepSeek, Groq, OpenRouter, vLLM, and xAI to ride OpenAI-compatible families while declaring only the provider-local deltas they need.
  priority: should
  stability: evolving

- id: reqllm.package.runtime_telemetry
  statement: ReqLlmNext shall expose a stable `ReqLlmNext.Telemetry` kernel for request, plan, execution-stack, stream, provider-request, fixture, and realtime instrumentation so application code and compat tooling can observe the runtime without parsing provider-specific payloads.
  priority: should
  stability: evolving

- id: reqllm.package.utility_proof_depth
  statement: Provider-owned utility helpers shall keep representative request-execution proof lanes in addition to builder-level tests so files, batches, vector stores, background flows, and similar non-canonical utilities stay honest about their integration depth without pretending to be part of the cross-provider facade.
  priority: should
  stability: evolving

- id: reqllm.package.live_verifier_lane
  statement: ReqLlmNext shall keep a dedicated sparse live verifier lane for representative Anthropic, OpenAI, and Google integration checks so provider drift and fixture-refresh sanity can be exercised explicitly without expanding the replay-backed default suite or requiring live-provider access in normal CI.
  priority: should
  stability: evolving

- id: reqllm.package.zoi_struct_contracts
  statement: ReqLlmNext shall standardize package-owned structs on Zoi-backed schemas rather than plain `defstruct` declarations so canonical package, planning, response, runtime-state, and extension-manifest contracts expose explicit schema metadata, enforced required keys, and stable defaults.
  priority: should
  stability: evolving

- id: reqllm.package.support_tiers
  statement: ReqLlmNext shall accept all `LLMDB` models as public inputs, report support through explicit `:first_class`, `:best_effort`, and `{:unsupported, reason}` tiers, treat first-class support as a function of actual provider-owned surfaces rather than provider registration alone, allow handcrafted local provider structs such as Codex CLI to report `:first_class` only when their provider-owned surfaces are real, execute packaged non-first-class models through canonical families only when typed `LLMDB` runtime metadata is complete enough to do so safely, prove that path against a curated best-effort provider matrix instead of a single happy-path provider, and fail fast when packaged metadata is catalog-only, incomplete, or names an unknown execution family.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: command
  target: mix test
  execute: true
  covers:
    - reqllm.package.multi_provider_api
    - reqllm.package.fixture_replay
    - reqllm.package.execution_planning
    - reqllm.package.buffered_stream_metadata
    - reqllm.package.runtime_telemetry
    - reqllm.package.support_tiers

- kind: command
  target: mix test test/public_api
  execute: true
  covers:
    - reqllm.package.multi_provider_api
    - reqllm.package.support_tiers

- kind: command
  target: mix test test/public_api/media_test.exs test/providers/openai/wire_images_test.exs test/providers/openai/wire_transcriptions_test.exs test/providers/openai/wire_speech_test.exs test/transcription/audio_input_test.exs
  execute: true
  covers:
    - reqllm.package.multi_provider_api
    - reqllm.package.fixture_replay

- kind: command
  target: mix test test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning

- kind: command
  target: mix test test/wire/streaming_test.exs test/wire/streaming_optional_callbacks_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning

- kind: command
  target: mix test test/model_profile_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning
    - reqllm.package.compile_time_extensions

- kind: command
  target: mix test test/best_effort_runtime_test.exs test/public_api/support_status_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning
    - reqllm.package.support_tiers

- kind: command
  target: mix test test/best_effort_runtime_test.exs test/coverage/best_effort_provider_matrix_test.exs test/public_api/support_status_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning
    - reqllm.package.support_tiers

- kind: command
  target: mix test test/providers/cohere test/providers/deepseek test/providers/elevenlabs test/providers/groq test/providers/openrouter test/providers/vllm test/providers/xai test/providers/zenmux test/providers/google test/providers/codex_cli test/model_profile_test.exs test/wire/resolver_test.exs
  execute: true
  covers:
    - reqllm.package.compile_time_extensions

- kind: command
  target: mix test test/providers/openai/client_test.exs test/providers/openai/background_test.exs test/providers/openai/files_test.exs test/providers/openai/vector_stores_test.exs test/providers/openai/batches_test.exs
  execute: true
  covers:
    - reqllm.package.provider_specific_utilities
    - reqllm.package.utility_proof_depth

- kind: command
  target: mix test test/req_llm_next/realtime_adapter_contract_test.exs test/req_llm_next/realtime_test.exs
  execute: true
  covers:
    - reqllm.package.execution_planning
    - reqllm.package.buffered_stream_metadata

- kind: command
  target: mix test test/model_slices/anthropic_haiku_4_5_test.exs
  execute: true
  covers:
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/model_slices/openai_gpt_4o_mini_test.exs
  execute: true
  covers:
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test.starter_slice
  execute: true
  covers:
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/coverage/anthropic_comprehensive_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/coverage/openai_comprehensive_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/coverage/openai_websocket_coverage_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/provider_features/anthropic_beta_features_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/provider_features/anthropic_advanced_messages_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test test/provider_features/google_native_surfaces_test.exs
  execute: true
  covers:
    - reqllm.package.fixture_replay
    - reqllm.package.model_slice_verification

- kind: command
  target: mix test.live_verifiers
  execute: true
  covers:
    - reqllm.package.live_verifier_lane

- kind: command
  target: mix test test/env_test.exs
  execute: true
  covers:
    - reqllm.package.local_env_loading

- kind: command
  target: mix test test/providers/anthropic
  execute: true
  covers:
    - reqllm.package.provider_specific_utilities

- kind: command
  target: mix test test/operation_planner_test.exs test/providers/anthropic/wire_messages_test.exs test/families/openai_compatible/wire_chat_test.exs test/providers/openai/wire_responses_request_test.exs
  execute: true
  covers:
    - reqllm.package.provider_native_input_isolation

- kind: command
  target: mix test test/req_llm_next/extensions/manifest_test.exs test/req_llm_next/extensions/dsl_test.exs test/req_llm_next/extensions/manifest_verifier_test.exs
  execute: true
  covers:
    - reqllm.package.compile_time_extensions

- kind: command
  target: mix test test/stream_response_test.exs test/executor/stream_state_test.exs test/req_llm_next/response/materializer_test.exs
  execute: true
  covers:
    - reqllm.package.zoi_struct_contracts
```
