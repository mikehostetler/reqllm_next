# Model Input Boundary

Current-truth public model-input contract for ReqLlmNext 2.0.

<!-- covers: reqllm.model_input.accepted_forms reqllm.model_input.llmdb_resolution reqllm.model_input.fail_fast -->

```spec-meta
id: reqllm.model_input
kind: model_input
status: active
summary: Narrow public model boundary for `model_spec` strings and `%LLMDB.Model{}` values, including handcrafted structs as a first-class local-iteration hook.
surface:
  - README.md
  - AGENTS.md
  - guides/package_thesis.md
  - lib/req_llm_next.ex
  - lib/req_llm_next/model_resolver.ex
  - lib/req_llm_next/realtime.ex
  - test/public_api/contract_test.exs
  - test/public_api/text_generation_test.exs
  - test/model_resolver_test.exs
  - test/req_llm_next/realtime_test.exs
decisions:
  - reqllm.decision.model_input_boundary
  - reqllm.decision.zoi_backed_struct_contracts
  - reqllm.decision.live_verifier_tests
  - reqllm.decision.provider_expansion_strategy
```

## Requirements

```spec-requirements
- id: reqllm.model_input.accepted_forms
  statement: ReqLlmNext public runtime APIs shall accept model input only as an `LLMDB` `model_spec` string or a `%LLMDB.Model{}`, including handcrafted `%LLMDB.Model{}` values used for local iteration, unreleased models, and local providers such as the Codex CLI spike, and that narrow boundary shall stay stable across the top-level text, object, media, embedding, and support-introspection facade plus the shared realtime core and sparse live verifier suites even as concrete provider and family implementations are co-located into internal slice homes, the provider roster grows through family-first expansion, and packaged models resolve into first-class or best-effort support tiers.
  priority: must
  stability: evolving

- id: reqllm.model_input.llmdb_resolution
  statement: String `model_spec` input shall delegate parsing and model resolution semantics to `LLMDB` rather than reimplementing model-spec parsing inside ReqLlmNext.
  priority: must
  stability: evolving

- id: reqllm.model_input.fail_fast
  statement: The model boundary shall fail fast on tuples, ad hoc maps, unsupported types, or invalid model metadata and shall not let raw unvalidated model input continue into execution, while leaving later provider-native helper validation and surface-specific request validation to the planning boundary rather than reintroducing raw model checks downstream, and the public contract lane shall load the top-level facade before export assertions so model-boundary contract coverage is checking the real compiled API surface.
  priority: must
  stability: evolving

- id: reqllm.model_input.zoi_handoff_contracts
  statement: Accepted model input shall hand off into Zoi-backed internal package contracts such as `ModelProfile`, `ExecutionMode`, `ExecutionPlan`, `Response`, `StreamResponse`, and realtime command or event or session state rather than into plain ad hoc structs so the public boundary feeds explicit internal schemas, and realtime adapter behavior above that boundary shall continue to operate on resolved models instead of inventing alternate model descriptor inputs.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/model_input_boundary.spec.md
  covers:
    - reqllm.model_input.accepted_forms
    - reqllm.model_input.llmdb_resolution
    - reqllm.model_input.fail_fast
    - reqllm.model_input.zoi_handoff_contracts

- kind: command
  target: mix test test/model_resolver_test.exs test/public_api/contract_test.exs test/public_api/text_generation_test.exs test/public_api/codex_cli_test.exs test/public_api/media_test.exs test/req_llm_next/realtime_test.exs
  execute: true
  covers:
    - reqllm.model_input.accepted_forms
    - reqllm.model_input.llmdb_resolution
    - reqllm.model_input.fail_fast

- kind: command
  target: mix test test/public_api/support_status_test.exs
  execute: true
  covers:
    - reqllm.model_input.accepted_forms
    - reqllm.model_input.llmdb_resolution
    - reqllm.model_input.fail_fast
```
