# Enforcement

Current-truth boundary-enforcement contract for ReqLlmNext.

<!-- covers: reqllm.enforcement.raw_model_boundary reqllm.enforcement.runtime_hard_fail reqllm.enforcement.zoi_for_facts -->

```spec-meta
id: reqllm.enforcement
kind: enforcement
status: active
summary: Runtime hard-fail validation and strict model-boundary enforcement for canonical runtime objects.
surface:
  - .spec/specs/enforcement.spec.md
  - lib/req_llm_next/model_resolver.ex
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/operation_planner.ex
```

## Requirements

```spec-requirements
- id: reqllm.enforcement.raw_model_boundary
  statement: Raw `%LLMDB.Model{}` input and model-spec parsing shall be accepted only at the model boundary and shall not survive into execution after `ModelProfile`, `ExecutionMode`, and `ExecutionPlan` are constructed.
  priority: must
  stability: evolving

- id: reqllm.enforcement.runtime_hard_fail
  statement: ReqLlmNext shall use runtime hard-fail validation for invalid model metadata, unsupported profile combinations, unsupported surface-parameter combinations, unsupported media operations, wrong-provider provider-native helper inputs, raw tool maps on non-owning surfaces, unsupported local CLI context shapes such as assistant tool-call history on Codex CLI text lanes, missing required continuation state, missing typed runtime metadata for best-effort providers, catalog-only packaged models that do not map to a real first-class provider-owned surface, unknown execution families, unknown keys, invalid enums, and unsafe source combinations rather than best-effort fallback behavior, while allowing only explicit manifest-declared provider-default and global-default family fallbacks and hard-failing compile-time extension manifests that violate duplicate-id, missing-reference, seam-ownership, or seam-module guarantees, without treating family-local semantic, wire, or transport seam overrides as invalid merely because a shared fallback registry already defines the same seam key.
  priority: must
  stability: evolving

- id: reqllm.enforcement.zoi_for_facts
  statement: `zoi` or an equivalent strict validation layer shall validate canonical facts and shapes, but it shall not become the mechanism that decides planning policy or transport behavior.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/enforcement.spec.md
  covers:
    - reqllm.enforcement.raw_model_boundary
    - reqllm.enforcement.runtime_hard_fail
    - reqllm.enforcement.zoi_for_facts

- kind: command
  target: mix test test/model_resolver_test.exs test/public_api/contract_test.exs test/public_api/media_test.exs test/public_api/codex_cli_test.exs test/req_llm_next/validation_test.exs
  execute: true
  covers:
    - reqllm.enforcement.raw_model_boundary
    - reqllm.enforcement.runtime_hard_fail

- kind: command
  target: mix test test/public_api/support_status_test.exs test/best_effort_runtime_test.exs
  execute: true
  covers:
    - reqllm.enforcement.runtime_hard_fail
```
