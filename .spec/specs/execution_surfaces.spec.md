# Execution Surfaces

Current-truth endpoint-style support contract for ReqLlmNext 2.0.

<!-- covers: reqllm.execution_surfaces.support_unit reqllm.execution_surfaces.non_cartesian reqllm.execution_surfaces.surface_selection reqllm.execution_surfaces.transport_variants -->

```spec-meta
id: reqllm.execution_surfaces
kind: execution_surface
status: active
summary: Explicit named execution surfaces as the support unit for endpoint styles.
surface:
  - lib/req_llm_next/execution_surface.ex
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/model_profile/surface_catalog.ex
  - lib/req_llm_next/model_profile/surface_catalog/**/*.ex
  - lib/req_llm_next/families/**/*surface_catalog*.ex
  - lib/req_llm_next/providers/**/*surface_catalog*.ex
  - lib/req_llm_next/operation_planner.ex
decisions:
  - reqllm.decision.execution_surface_support_unit
```

## Requirements

```spec-requirements
- id: reqllm.execution_surfaces.support_unit
  statement: ReqLlmNext shall represent each valid endpoint style as a named `ExecutionSurface` that bundles semantic protocol, wire format, transport, session compatibility, feature tags, and owning family id for one operation family, including provider-native structured-output strategies, provider-native request-preparation rules, any session-runtime seam selection implied by that semantic family, request-style media surfaces when a provider exposes standalone image, transcription, or speech APIs, and non-HTTP local-process surfaces when a first-class provider owns a CLI runtime, including provider-local responses-first surface ids such as xAI text and object Responses lanes, Google embedding and image surfaces inside the native Google family, provider-local media-family overrides such as xAI image generation, Codex CLI text and object lanes with a local-process transport, and generic best-effort surfaces synthesized from typed `LLMDB.Model.execution` metadata for non-first-class providers.
  priority: must
  stability: evolving

- id: reqllm.execution_surfaces.non_cartesian
  statement: ReqLlmNext shall not infer endpoint support from a cartesian product of independent protocol, wire-format, and transport lists and shall instead resolve only declared execution surfaces through surface catalog modules selected by the compiled extension manifest and defined in explicit provider or family definition packs or through the typed `LLMDB.Model.execution` contract for non-first-class best-effort providers, while allowing one provider-owned catalog module to declare multiple closely related media surfaces when separate catalog files would add only low-value indirection.
  priority: must
  stability: evolving

- id: reqllm.execution_surfaces.surface_selection
  statement: The planner shall choose exactly one primary `ExecutionSurface` for an `ExecutionPlan`, may only choose fallback surfaces already declared in `ModelProfile`, and shall apply explicit compatibility checks for transport, structured output, tools, reasoning, streaming, and session semantics before selecting the highest-ranked matching surface for the active mode.
  priority: must
  stability: evolving

- id: reqllm.execution_surfaces.transport_variants
  statement: ReqLlmNext may declare multiple transport variants for one semantic protocol family, such as OpenAI Responses over HTTP SSE and WebSocket or provider-owned local-process transports for CLI-backed surfaces, and explicit transport preference shall only select among those declared surfaces and fallbacks.
  priority: should
  stability: evolving

- id: reqllm.execution_surfaces.realtime_outside_surface_catalog
  statement: First-class realtime session flows may live outside the normal request-surface catalog when the package owns canonical realtime commands, events, and session reduction separately from the request planner, but provider adapters for those flows shall still honor the same semantic, wire, transport, and provider boundary ownership rules.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/execution_surfaces.spec.md
  covers:
    - reqllm.execution_surfaces.support_unit
    - reqllm.execution_surfaces.non_cartesian
    - reqllm.execution_surfaces.surface_selection

- kind: command
  target: mix test test/operation_planner_test.exs test/providers/xai/execution_stack_test.exs test/providers/zenmux/execution_stack_test.exs test/providers/google/execution_stack_test.exs test/providers/google/wire_embeddings_test.exs test/providers/google/wire_images_test.exs test/provider_features/google_native_surfaces_test.exs test/providers/elevenlabs/execution_stack_test.exs test/providers/cohere/execution_stack_test.exs test/providers/codex_cli/execution_stack_test.exs
  execute: true
  covers:
    - reqllm.execution_surfaces.support_unit
    - reqllm.execution_surfaces.surface_selection
    - reqllm.execution_surfaces.transport_variants
    - reqllm.execution_surfaces.realtime_outside_surface_catalog

- kind: command
  target: mix test test/best_effort_runtime_test.exs
  execute: true
  covers:
    - reqllm.execution_surfaces.support_unit
    - reqllm.execution_surfaces.non_cartesian
    - reqllm.execution_surfaces.surface_selection
```
