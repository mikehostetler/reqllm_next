# Architecture Direction

Current-truth boundary and execution-layer contract for ReqLlmNext 2.0.

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers -->

```spec-meta
id: reqllm.architecture
kind: architecture
status: active
summary: Current-truth runtime boundary and layer-separation contract for model input and execution flow, including handcrafted `LLMDB.Model` support at the boundary, a fully plan-driven execution spine, the thin top-level facade, and the separated execution stack.
surface:
  - README.md
  - AGENTS.md
  - .spec/README.md
  - guides/package_thesis.md
  - guides/anthropic_openai_compatibility.md
  - lib/req_llm_next.ex
  - lib/req_llm_next/anthropic.ex
  - lib/req_llm_next/execution_mode.ex
  - lib/req_llm_next/execution_plan.ex
  - lib/req_llm_next/execution_surface.ex
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/model_resolver.ex
  - lib/req_llm_next/operation_planner.ex
  - lib/req_llm_next/policy_rules.ex
  - lib/req_llm_next/execution_modules.ex
  - lib/req_llm_next/runtime_metadata.ex
  - lib/req_llm_next/support.ex
  - lib/req_llm_next/realtime.ex
  - lib/req_llm_next/response/output_item.ex
  - lib/req_llm_next/telemetry.ex
  - .spec/specs/public_api.spec.md
  - test/public_api/**/*.exs
  - test/model_resolver_test.exs
  - test/operation_planner_test.exs
decisions:
  - reqllm.decision.model_input_boundary
  - reqllm.decision.execution_layers
  - reqllm.decision.execution_plan_bridge
  - reqllm.decision.profile_descriptive_not_prescriptive
  - reqllm.decision.execution_mode_first_class
  - reqllm.decision.execution_surface_support_unit
  - reqllm.decision.five_scope_policy_rules
  - reqllm.decision.layer_scoped_plan_aware_adapters
  - reqllm.decision.media_operation_families
  - reqllm.decision.canonical_output_items
  - reqllm.decision.transport_agnostic_realtime_core
  - reqllm.decision.runtime_telemetry_kernel
  - reqllm.decision.zoi_backed_struct_contracts
  - reqllm.decision.live_verifier_tests
  - reqllm.decision.provider_expansion_strategy
  - reqllm.decision.llmdb_best_effort_runtime
```

## Requirements

```spec-requirements
- id: reqllm.architecture.model_input_boundary
  statement: ReqLlmNext runtime APIs shall accept model inputs only as `LLMDB` `model_spec` strings or `%LLMDB.Model{}` values, with handcrafted `LLMDB.Model` structs supported as a local-iteration boundary hook, and the top-level public API contract lane shall load the compiled facade before export assertions so architecture-boundary verification stays about the actual runtime module rather than code-loading order.
  priority: must
  stability: evolving

- id: reqllm.architecture.facts_mode_policy_plan
  statement: ReqLlmNext architecture shall normalize model facts into `ModelProfile`, request intent into `ExecutionMode`, resolve compatibility-aware surface policy, run surface-owned request preparation, and materialize a single `ExecutionPlan` before downstream execution, including manifest-backed provider-scoped descriptive fact extraction for first-class providers, typed `LLMDB.Provider.runtime` and `LLMDB.Model.execution` metadata as the upstream contract for best-effort providers without dedicated slice registrations, family-owned or metadata-driven surface catalog resolution before planning, manifest-backed or generic runtime-module lookup for provider, session-runtime, protocol, wire, and transport layers, honoring explicit transport and session intent when a matching surface exists, validating surface-specific parameter compatibility before wire encoding, preparing continuation state in session runtime before transport execution, and routing both streaming and request-style execution through explicit transport modules across text, object, embedding, image, transcription, and speech operations, including provider-owned Google embedding and image lanes inside the native Google family plus first-class local-process text and object lanes such as the Codex CLI spike that keep auth outside the package boundary, while allowing public docs to distinguish first-class and best-effort support tiers without splitting the runtime into different planner architectures.
  priority: must
  stability: evolving

- id: reqllm.architecture.execution_layers
  statement: ReqLlmNext architecture shall separate realtime adapter, realtime session reduction, semantic protocol, wire format, transport, provider, session-runtime, and telemetry-kernel concerns so canonical request and event meaning, wire envelopes, persistent execution state, byte movement, and diagnostics can evolve independently across HTTP, WebSocket, and local-process transports, and canonical response normalization shall expose explicit result channels on top of output items so higher-level helpers do not have to recover those distinctions from provider metadata while replay-backed suites and sparse live verifier suites continue to exercise the same execution spine rather than alternate ad hoc paths.
  priority: must
  stability: evolving

- id: reqllm.architecture.zoi_struct_contracts
  statement: ReqLlmNext architecture shall model package-owned planning, response, streaming, runtime-state, and extension-manifest structs as Zoi-backed schema contracts so the execution spine carries explicit required fields, defaults, and introspection instead of ad hoc plain structs.
  priority: should
  stability: evolving

- id: reqllm.architecture.provider_specific_utilities
  statement: ReqLlmNext architecture may expose provider-scoped utility modules for non-canonical provider endpoints and provider-native helper shapes such as Anthropic web search, web fetch, code execution, MCP, computer use, token counting, files, and batches, but those utilities and helper shapes shall remain outside the top-level cross-provider facade and outside the core execution-plan layer stack except where a selected provider surface explicitly accepts them, and provider expansion shall prefer reusing existing execution families with provider-owned deltas before introducing new shared abstractions.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: README.md
  covers:
    - reqllm.architecture.model_input_boundary
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.execution_layers

- kind: source_file
  target: AGENTS.md
  covers:
    - reqllm.architecture.model_input_boundary
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.execution_layers

- kind: source_file
  target: .spec/specs/architecture.spec.md
  covers:
    - reqllm.architecture.model_input_boundary
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.execution_layers
    - reqllm.architecture.zoi_struct_contracts

- kind: command
  target: mix test test/model_resolver_test.exs test/public_api test/providers/codex_cli/execution_stack_test.exs
  execute: true
  covers:
    - reqllm.architecture.model_input_boundary

- kind: source_file
  target: .spec/specs/architecture.spec.md
  covers:
    - reqllm.architecture.provider_specific_utilities

- kind: command
  target: mix test test/best_effort_runtime_test.exs test/public_api/support_status_test.exs test/public_api/codex_cli_test.exs
  execute: true
  covers:
    - reqllm.architecture.facts_mode_policy_plan
    - reqllm.architecture.model_input_boundary
```
