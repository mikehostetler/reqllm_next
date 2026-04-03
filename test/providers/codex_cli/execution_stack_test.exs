defmodule ReqLlmNext.Providers.CodexCLI.ExecutionStackTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{ExecutionModules, OperationPlanner, Schema, TestModels}

  test "plans Codex CLI text generation through the provider-owned local transport" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.codex_cli(),
        :text,
        "Explain the result"
      )

    resolution = ExecutionModules.resolve(plan)

    assert plan.model.family == :codex_cli
    assert plan.surface.semantic_protocol == :codex_cli
    assert plan.surface.wire_format == :codex_cli_jsonl
    assert plan.surface.transport == :codex_cli
    assert resolution.provider_mod == ReqLlmNext.Providers.CodexCLI
    assert resolution.protocol_mod == ReqLlmNext.SemanticProtocols.CodexCLI
    assert resolution.wire_mod == ReqLlmNext.Wire.CodexCLI
    assert resolution.transport_mod == ReqLlmNext.Transports.CodexCLI
  end

  test "plans Codex CLI object generation through native output-schema mode" do
    {:ok, plan} =
      OperationPlanner.plan(
        TestModels.codex_cli(),
        :object,
        "Return a person object",
        compiled_schema: Schema.compile!(name: [type: :string, required: true])
      )

    assert plan.model.family == :codex_cli
    assert plan.surface.semantic_protocol == :codex_cli
    assert plan.surface.features.structured_output == :native_json_schema
  end
end
