# Operation Planner

Current-truth planner-boundary contract for ReqLlmNext 2.0.

<!-- covers: reqllm.operation_planner.planner_boundary reqllm.operation_planner.assembly_scope reqllm.operation_planner.no_io -->

```spec-meta
id: reqllm.operation_planner
kind: planner
status: active
summary: Planner boundary that turns profile, mode, and policy into one execution plan.
surface:
  - lib/req_llm_next/operation_planner.ex
  - lib/req_llm_next/surface_preparation.ex
  - lib/req_llm_next/providers/**/*surface_preparation*.ex
  - lib/req_llm_next/execution_mode.ex
  - lib/req_llm_next/execution_plan.ex
  - lib/req_llm_next/policy_rules.ex
  - test/operation_planner_test.exs
decisions:
  - reqllm.decision.execution_mode_first_class
  - reqllm.decision.execution_surface_support_unit
  - reqllm.decision.five_scope_policy_rules
```

## Requirements

```spec-requirements
- id: reqllm.operation_planner.planner_boundary
  statement: ReqLlmNext shall keep one planner boundary that turns `ModelProfile`, `ExecutionMode`, and ordered policy rules into one resolved `ExecutionPlan`.
  priority: must
  stability: evolving

- id: reqllm.operation_planner.assembly_scope
  statement: The planner boundary shall own mode normalization, rule evaluation, compatibility-aware surface selection, parameter normalization, explicit transport and session preference handling, fallback planning, surface-specific parameter validation, documented provider-native dependency validation, provider-native helper acceptance or rejection, surface-owned request preparation, session planning, and adapter selection, including request-style media operations, provider-owned Google embedding and image validation including rejection of unsupported Imagen `:size` overrides before provider execution, local CLI surface validation such as Codex CLI rejecting canonical tool calls and assistant tool-call history before local transport execution, OpenAI-compatible provider overrides such as DeepSeek chat families and xAI responses-first surfaces with provider-local built-in tool helpers plus image-family overrides, Anthropic context-management validation such as `clear_thinking_20251015` requiring Anthropic thinking to be enabled, and resolution of surface-preparation, session-runtime, and adapter seams from the compiled extension manifest rather than from global imperative registries, while using the chosen surface family and typed `LLMDB` execution metadata to plan best-effort providers without reintroducing provider-name inference into the planner.
  priority: must
  stability: evolving

- id: reqllm.operation_planner.no_io
  statement: The planner boundary shall not encode provider payloads, open sockets, send HTTP requests, or decode provider events.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/operation_planner.spec.md
  covers:
    - reqllm.operation_planner.planner_boundary
    - reqllm.operation_planner.assembly_scope
    - reqllm.operation_planner.no_io

- kind: command
  target: mix test test/operation_planner_test.exs test/providers/codex_cli/execution_stack_test.exs
  execute: true
  covers:
    - reqllm.operation_planner.planner_boundary
    - reqllm.operation_planner.assembly_scope

- kind: command
  target: mix test test/providers/anthropic/surface_preparation_messages_test.exs test/public_api/codex_cli_test.exs
  execute: true
  covers:
    - reqllm.operation_planner.assembly_scope

- kind: command
  target: mix test test/providers/xai/execution_stack_test.exs test/providers/xai/wire_responses_test.exs test/providers/zenmux/execution_stack_test.exs test/providers/zenmux/wire_responses_test.exs test/providers/google/execution_stack_test.exs test/providers/google/wire_embeddings_test.exs test/providers/google/wire_images_test.exs test/provider_features/google_native_surfaces_test.exs
  execute: true
  covers:
    - reqllm.operation_planner.assembly_scope

- kind: command
  target: mix test test/operation_planner_test.exs test/best_effort_runtime_test.exs
  execute: true
  covers:
    - reqllm.operation_planner.planner_boundary
    - reqllm.operation_planner.assembly_scope
```
