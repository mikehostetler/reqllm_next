---
id: reqllm.decision.execution_layers
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.package
---

# Separate Semantic Protocol, Wire Format, and Transport

## Context

The current spike implementation uses `ReqLlmNext.Wire.*` modules that blend several concerns:

1. semantic API-family meaning
2. provider-facing routes and envelopes
3. transport assumptions about SSE or WebSocket delivery

That fusion made the architecture harder to reason about, especially for APIs such as OpenAI Responses where the same semantic protocol can run over HTTP/SSE or WebSocket with different client-event envelopes, and for CLI-backed runtimes where provider-owned JSONL framing should not collapse wire and transport concerns back together.

## Decision

ReqLlmNext 2.0 treats the execution stack as four separate concerns:

1. semantic protocol owns API-family meaning and canonical event decoding
2. wire format owns routes, content types, request envelopes, and inbound frame parsing
3. transport owns connection lifecycle and byte or frame movement across network or local-process runtimes
4. provider owns auth and endpoint roots

The planner is responsible for choosing semantic protocol, wire format, and transport for a request.

That rule applies equally to provider-owned local CLI surfaces. A first-class CLI provider may bind a local-process transport, a provider-owned wire format, and a provider-owned semantic protocol without special casing those flows in shared planner or executor code.

ReqLlmNext now embodies those concerns as distinct lower-layer seams, with runtime module resolution, session runtime, transport dispatch, and shared response materialization all driven from the plan instead of through transitional mixed ownership.

## Consequences

The long-form specs and README can describe WebSocket and SSE execution without overloading the word "wire."

Future refactors should keep sharpening these boundaries instead of creating larger mixed modules or reintroducing cross-layer shortcuts.

Compatibility diagnostics and source ownership become clearer because semantic mistakes, envelope mistakes, and transport mistakes now have separate homes.
