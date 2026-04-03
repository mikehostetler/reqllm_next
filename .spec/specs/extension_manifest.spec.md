# Extension Manifest

Current-truth contract for the compile-time extension manifest and its plain runtime data model.

<!-- covers: reqllm.extension_manifest.plain_runtime_contract reqllm.extension_manifest.family_precedence reqllm.extension_manifest.rule_precedence reqllm.extension_manifest.narrow_seams -->

```spec-meta
id: reqllm.extension_manifest
kind: architecture
status: active
summary: Declarative family and rule data that preserve a default happy path while allowing narrow opt-in execution overrides.
surface:
  - .spec/decisions/compile_time_extension_manifest.md
  - .spec/specs/extension_manifest.spec.md
  - guides/extension_architecture.md
  - lib/req_llm_next/extensions.ex
  - lib/req_llm_next/extensions/**/*.ex
  - lib/req_llm_next/families/**/definition.ex
  - lib/req_llm_next/providers/**/definition.ex
  - test/req_llm_next/extensions/**/*.exs
```

## Requirements

```spec-requirements
- id: reqllm.extension_manifest.plain_runtime_contract
  statement: ReqLlmNext shall model execution extension behavior as plain runtime data made of providers, families, rules, criteria, seam patches, and manifests so the runtime consumes a stable contract independent of any authoring DSL, with built-in declaration packs discovered from provider and family slice homes such as `lib/req_llm_next/families/**/definition.ex` and `lib/req_llm_next/providers/**/definition.ex`, merged into one compiled manifest at compile time, and expanded into a manifest-backed runtime registry for globally-addressable provider, session-runtime, protocol, wire, and transport seam keys, including provider-owned local-process transport keys for CLI-backed slices such as Codex CLI, plus plan-local seam overrides for provider or family stacks that intentionally shadow the shared fallback registry.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.family_precedence
  statement: Default execution families shall resolve deterministically from declarative criteria using explicit precedence, then fall back through provider-registered default families and finally global default families, so the happy path is stable and inspectable without reintroducing central provider branching, while allowing provider-local chat and media families such as OpenRouter routing overrides, Groq transcription support, Google embedding and image surfaces declared inside the native Google family stack, or xAI image-generation overrides on top of a responses-first baseline to shadow provider baselines without mutating the shared family defaults, and allowing simple providers such as vLLM to register only provider seams and intentionally reuse the shared default family unchanged.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.rule_precedence
  statement: Opt-in override rules shall apply in deterministic order from broad to narrow so later, more specific patches can refine the family default without reintroducing omniscient central branching.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.narrow_seams
  statement: Extension declarations shall only patch explicit seams such as provider registration, provider facts, surface catalog construction, surface preparation, session-runtime mapping, semantic protocol mapping, wire mapping, transport mapping, realtime adapter mapping, adapters, and provider-native utility homes, including provider-owned media families, request-style media wires, or local-process CLI transports when needed, and shared runtime code shall consume those seams instead of branching on provider atoms directly, so providers such as xAI can add provider-local tool helpers and responses or media wire swaps and Codex CLI can add a provider-local wire, protocol, and local transport stack without reintroducing shared provider branching.
  priority: must
  stability: evolving

- id: reqllm.extension_manifest.spark_authoring_layer
  statement: ReqLlmNext may use Spark as a compile-time authoring DSL for built-in extension declarations, but that authoring layer shall compile to the plain manifest contract and compiled manifest modules rather than becoming the runtime extension API itself, and the contributor-facing DSL should prefer intention-shaped blocks such as `register`, `match`, `stack`, `patch`, and family inheritance over exposing raw runtime seam structs directly.
  priority: should
  stability: evolving

- id: reqllm.extension_manifest.compile_time_verification
  statement: ReqLlmNext shall verify merged extension manifests at compile time for duplicate ids, missing default-family references, missing global defaults, invalid family references in rules, illegal seam ownership, and missing seam modules so the declaration layer enforces architectural boundaries instead of merely describing them, while still allowing provider or family definition packs to override shared semantic, wire, transport, or utility seam keys locally for their resolved stacks.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/extension_manifest.spec.md
  covers:
    - reqllm.extension_manifest.plain_runtime_contract
    - reqllm.extension_manifest.family_precedence
    - reqllm.extension_manifest.rule_precedence
    - reqllm.extension_manifest.narrow_seams
    - reqllm.extension_manifest.spark_authoring_layer

- kind: command
  target: mix test test/req_llm_next/extensions/manifest_test.exs test/req_llm_next/extensions/dsl_test.exs
  execute: true
  covers:
    - reqllm.extension_manifest.plain_runtime_contract
    - reqllm.extension_manifest.family_precedence
    - reqllm.extension_manifest.rule_precedence
    - reqllm.extension_manifest.spark_authoring_layer

- kind: command
  target: mix test test/req_llm_next/extensions/manifest_verifier_test.exs
  execute: true
  covers:
    - reqllm.extension_manifest.compile_time_verification

- kind: command
  target: mix test test/providers/cohere/execution_stack_test.exs test/providers/deepseek/execution_stack_test.exs test/providers/elevenlabs/execution_stack_test.exs test/providers/groq/execution_stack_test.exs test/providers/openrouter/execution_stack_test.exs test/providers/vllm/execution_stack_test.exs test/providers/xai/execution_stack_test.exs test/providers/zenmux/execution_stack_test.exs test/providers/google/execution_stack_test.exs test/providers/google/wire_embeddings_test.exs test/providers/google/wire_images_test.exs test/provider_features/google_native_surfaces_test.exs test/providers/codex_cli/execution_stack_test.exs test/model_profile_test.exs
  execute: true
  covers:
    - reqllm.extension_manifest.plain_runtime_contract
    - reqllm.extension_manifest.family_precedence
    - reqllm.extension_manifest.narrow_seams
```
