---
id: reqllm.decision.execution_surface_support_unit
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.model_profile
  - reqllm.execution_surfaces
  - reqllm.execution_plan
---

# ExecutionSurface Is the Unit of Endpoint Support

## Context

ReqLlmNext needs to support multiple endpoint styles for the same provider and sometimes for the same model. Treating semantic protocol, wire format, and transport as separate lists suggests a free cartesian product of combinations that real provider APIs do not actually support.

For example, one API family may be available over both HTTP/SSE and WebSocket, but with different wire envelopes, session compatibility, and fallback behavior. A provider may also expose a first-class local CLI runtime whose endpoint style is best represented as its own local-process surface rather than as an implied transport flag on an existing HTTP family.

## Decision

ReqLlmNext 2.0 uses named `ExecutionSurface` entries as the stable support unit for endpoint styles.

Each `ExecutionSurface` bundles:

1. one operation family
2. one semantic protocol
3. one wire format
4. one transport, whether that is HTTP, WebSocket, or a provider-owned local-process runtime
5. session compatibility
6. feature tags and modality support relevant to that endpoint style

`ModelProfile` declares the surfaces a model supports, and planning chooses among those declared surfaces.

## Consequences

Support is explicit and easier to inspect, test, and override.

Fallback planning becomes more coherent because the system falls back from one named surface to another rather than recomputing combinations from independent lists.

Adding a new endpoint style usually means adding a new surface plus the matching layer implementations instead of overloading existing metadata fields, whether the new style is another network transport or a CLI-backed local-process lane.
