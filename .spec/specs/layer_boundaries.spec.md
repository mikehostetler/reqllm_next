# Layer Boundaries

Current-truth execution-layer handoff contract for ReqLlmNext 2.0.

<!-- covers: reqllm.layer_boundaries.separated_io reqllm.layer_boundaries.plan_aware_adapters reqllm.layer_boundaries.no_cross_layer_skips -->

```spec-meta
id: reqllm.layer_boundaries
kind: layer_boundaries
status: active
summary: Explicit handoff rules for provider, session runtime, transport, wire format, semantic protocol, and plan-aware adapters, with one deterministic layer stack per resolved plan and replay path.
surface:
  - AGENTS.md
  - lib/req_llm_next/execution_modules.ex
  - lib/req_llm_next/realtime.ex
  - lib/req_llm_next/telemetry.ex
  - lib/req_llm_next/families/**/*.ex
  - lib/req_llm_next/providers/**/*.ex
  - lib/req_llm_next/semantic_protocol.ex
  - lib/req_llm_next/transports/**/*.ex
  - lib/req_llm_next/fixtures.ex
decisions:
  - reqllm.decision.execution_layers
  - reqllm.decision.layer_scoped_plan_aware_adapters
  - reqllm.decision.execution_plan_bridge
  - reqllm.decision.transport_agnostic_realtime_core
  - reqllm.decision.runtime_telemetry_kernel
  - reqllm.decision.zoi_backed_struct_contracts
  - reqllm.decision.live_verifier_tests
```

## Requirements

```spec-requirements
- id: reqllm.layer_boundaries.separated_io
  statement: ReqLlmNext shall keep provider, session runtime, realtime adapter, realtime session reduction, transport, wire format, semantic protocol, and telemetry-kernel responsibilities separated so no layer skips across another layer's ownership boundary and each resolved plan binds one deterministic layer stack including explicit provider, protocol, wire, and transport modules resolved from manifest-declared seams and the compiled runtime registry across both streaming execution and request-style HTTP or local-process lanes, allowing provider-local wire swaps and family overrides such as Groq chat and transcription support, OpenRouter routing-aware request shaping, Google generateContent plus dedicated embedding and image wires inside one native provider family, Codex CLI local-process text and object execution with isolated working directories and external auth, or xAI Responses and image-family separation plus provider-local tool helper wires without mutating the shared family baseline, while also allowing simple providers such as vLLM or generic best-effort packaged providers to bind a provider module without adding unnecessary lower-layer indirection.
  priority: must
  stability: evolving

- id: reqllm.layer_boundaries.plan_aware_adapters
  statement: ReqLlmNext shall treat adapters as explicit layer-scoped patches selected through resolved extension seams after policy resolution so adapter application is constrained by the chosen plan and surface instead of one omniscient global adapter registry.
  priority: must
  stability: evolving

- id: reqllm.layer_boundaries.no_cross_layer_skips
  statement: No execution layer shall skip across another layer's ownership boundary by choosing transports in semantic protocol code, reinterpreting semantic meaning in wire code, introducing model-specific behavior in provider or transport code, deriving provider-native request flags in shared executor code after planning, resolving auth or endpoint roots outside the provider layer when generic runtime metadata is in use, performing provider-surface dependency validation such as Anthropic `clear_thinking_20251015` requirements or xAI built-in tool helper acceptance outside planner-owned surface-preparation seams, or performing session continuation derivation outside planner-owned session runtime seams.
  priority: must
  stability: evolving

- id: reqllm.layer_boundaries.replay_uses_recorded_stack
  statement: Fixture replay shall prefer the recorded or inferable surface from the fixture request itself over today's planned surface so replay keeps exercising the execution stack that originally produced the captured artifact, whether that artifact was a streaming capture, a request-style media response that must still route through the owning wire decoder, or a line-framed local-process capture such as Codex CLI JSONL output, while sparse live verifier suites above the runtime stack continue to use the same planner and execution layers rather than special-case provider shortcuts, including replay-backed Google embedding and image fixtures plus opt-in Google live verifiers that exercise the same native provider stack.
  priority: must
  stability: evolving

- id: reqllm.layer_boundaries.provider_utilities_outside_stack
  statement: Provider-specific utility modules for non-canonical endpoints shall sit outside the core execution-plan layer stack and may reuse provider auth or endpoint roots without becoming alternate semantic-protocol or wire layers for the main public API.
  priority: should
  stability: evolving

- id: reqllm.layer_boundaries.zoi_runtime_state
  statement: Package-owned structs that cross layer boundaries for streaming, response materialization, or transport state shall be modeled as Zoi-backed schema contracts so runtime handoffs keep explicit defaults and required fields rather than passing around plain ad hoc structs.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/layer_boundaries.spec.md
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.plan_aware_adapters
    - reqllm.layer_boundaries.no_cross_layer_skips
    - reqllm.layer_boundaries.replay_uses_recorded_stack
    - reqllm.layer_boundaries.provider_utilities_outside_stack
    - reqllm.layer_boundaries.zoi_runtime_state

- kind: source_file
  target: AGENTS.md
  covers:
    - reqllm.layer_boundaries.plan_aware_adapters

- kind: command
  target: mix test test/executor/stream_state_test.exs test/fixtures_test.exs test/operation_planner_test.exs test/providers/codex_cli/execution_stack_test.exs
  execute: true
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.replay_uses_recorded_stack

- kind: command
  target: mix test test/public_api/media_test.exs test/providers/openai/wire_images_test.exs test/providers/openai/wire_transcriptions_test.exs test/providers/openai/wire_speech_test.exs
  execute: true
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.replay_uses_recorded_stack

- kind: command
  target: mix test test/providers/google/wire_images_test.exs test/provider_features/google_native_surfaces_test.exs
  execute: true
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.replay_uses_recorded_stack

- kind: command
  target: mix test test/providers/xai/execution_stack_test.exs test/providers/xai/wire_responses_test.exs test/providers/zenmux/execution_stack_test.exs test/providers/zenmux/wire_chat_test.exs test/providers/zenmux/wire_responses_test.exs test/providers/google/execution_stack_test.exs test/providers/google/wire_generate_content_test.exs test/providers/google/wire_embeddings_test.exs test/providers/google/wire_images_test.exs test/providers/elevenlabs/execution_stack_test.exs test/providers/elevenlabs/wire_speech_test.exs test/providers/elevenlabs/wire_transcriptions_test.exs test/providers/cohere/execution_stack_test.exs test/providers/cohere/wire_chat_test.exs test/providers/codex_cli/execution_stack_test.exs test/public_api/codex_cli_test.exs
  execute: true
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.no_cross_layer_skips

- kind: command
  target: mix test test/best_effort_runtime_test.exs
  execute: true
  covers:
    - reqllm.layer_boundaries.separated_io
    - reqllm.layer_boundaries.no_cross_layer_skips

- kind: command
  target: mix test test/stream_response_test.exs test/executor/stream_state_test.exs test/req_llm_next/response/materializer_test.exs
  execute: true
  covers:
    - reqllm.layer_boundaries.zoi_runtime_state
```
