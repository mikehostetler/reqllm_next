# Model Profile

Current-truth descriptive model-facts contract for ReqLlmNext 2.0.

<!-- covers: reqllm.model_profile.descriptive_facts reqllm.model_profile.execution_surfaces_declared reqllm.model_profile.request_independent -->

```spec-meta
id: reqllm.model_profile
kind: model_profile
status: active
summary: Canonical descriptive model facts and execution-surface catalog.
surface:
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/model_profile/surface_catalog.ex
  - lib/req_llm_next/model_profile/surface_catalog/**/*.ex
  - lib/req_llm_next/model_profile/provider_facts.ex
  - lib/req_llm_next/model_profile/provider_facts/**/*.ex
  - lib/req_llm_next/families/**/*surface_catalog*.ex
  - lib/req_llm_next/providers/**/*surface_catalog*.ex
  - lib/req_llm_next/execution_surface.ex
  - lib/req_llm_next/operation_planner.ex
decisions:
  - reqllm.decision.profile_descriptive_not_prescriptive
  - reqllm.decision.execution_surface_support_unit
```

## Requirements

```spec-requirements
- id: reqllm.model_profile.descriptive_facts
  statement: ReqLlmNext shall normalize resolved model metadata into a request-independent `ModelProfile` that describes operations, features, modalities, limits, parameter defaults, constraints metadata, and session capabilities without choosing concrete request behavior, including manifest-backed provider-scoped descriptive fact extraction for normalized features such as Anthropic structured outputs, citations, context management, additional document input, provider-owned media operation support, Google distinctions between Gemini chat, embedding, dedicated image-generation, and obviously non-chat long-tail families, Codex CLI local text and object support with native output-schema capability but no canonical tool calling, and OpenAI-compatible provider deltas such as DeepSeek chat or reasoning behavior, Groq transcription-media routing, OpenRouter routing-aware chat overrides, xAI responses-first versus image-media routing plus native-structured-output support by model generation, and self-hosted providers such as vLLM that intentionally ride the shared OpenAI-compatible family without custom wire or protocol overrides, plus the resolved extension family id selected by declarative criteria and provider or global fallback rules or by typed `LLMDB.Model.execution` metadata for best-effort providers when no dedicated provider registration exists.
  priority: must
  stability: evolving

- id: reqllm.model_profile.execution_surfaces_declared
  statement: `ModelProfile` shall declare explicit named `ExecutionSurface` entries for supported endpoint styles instead of implying support from independent protocol, wire-format, and transport lists, including multiple transport variants for one semantic family when the provider truly supports them, provider-owned local-process surfaces when a CLI runtime is first-class, allowing one provider-owned media catalog to emit several explicit media-operation surfaces when the provider facts already disambiguate which family is active, and carrying an explicit owning family id on each surface whether that surface came from an extension-backed catalog or the generic typed-metadata best-effort catalog.
  priority: must
  stability: evolving

- id: reqllm.model_profile.request_independent
  statement: `ModelProfile` shall remain request-independent, serializable, and safe to cache, and it shall not contain chosen surfaces, prompt state, continuation state, session runtime handles, or network handles.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/model_profile.spec.md
  covers:
    - reqllm.model_profile.descriptive_facts
    - reqllm.model_profile.execution_surfaces_declared
    - reqllm.model_profile.request_independent

- kind: command
  target: mix test test/model_profile_test.exs test/operation_planner_test.exs test/providers/xai/provider_facts_test.exs test/providers/xai/execution_stack_test.exs test/providers/zenmux/provider_facts_test.exs test/providers/zenmux/execution_stack_test.exs test/providers/google/provider_facts_test.exs test/providers/google/execution_stack_test.exs test/providers/google/wire_embeddings_test.exs test/providers/google/wire_images_test.exs test/provider_features/google_native_surfaces_test.exs test/providers/elevenlabs/provider_facts_test.exs test/providers/elevenlabs/execution_stack_test.exs test/providers/cohere/provider_facts_test.exs test/providers/cohere/execution_stack_test.exs test/providers/codex_cli/execution_stack_test.exs
  execute: true
  covers:
    - reqllm.model_profile.descriptive_facts
    - reqllm.model_profile.execution_surfaces_declared

- kind: command
  target: mix test test/model_profile_test.exs test/best_effort_runtime_test.exs
  execute: true
  covers:
    - reqllm.model_profile.descriptive_facts
    - reqllm.model_profile.execution_surfaces_declared
```
