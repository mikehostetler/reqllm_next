defmodule ReqLlmNext.Extensions.Definitions.CodexCLI do
  @moduledoc """
  Codex CLI provider declarations.
  """

  use ReqLlmNext.Extensions.Definition

  providers do
    provider :codex_cli do
      default_family(:codex_cli)
      description("Local Codex CLI provider for isolated text and object execution")

      register do
        provider_module(ReqLlmNext.Providers.CodexCLI)
        provider_facts_module(ReqLlmNext.ModelProfile.ProviderFacts.CodexCLI)
      end
    end
  end

  families do
    family :codex_cli do
      priority(250)
      description("Local Codex CLI family")

      match do
        provider_ids([:codex_cli])
      end

      stack do
        surface_catalog_module(ReqLlmNext.ModelProfile.SurfaceCatalog.CodexCLI)

        surface_preparation_modules(codex_cli: ReqLlmNext.SurfacePreparation.CodexCLI)

        semantic_protocol_modules(codex_cli: ReqLlmNext.SemanticProtocols.CodexCLI)

        wire_modules(codex_cli_jsonl: ReqLlmNext.Wire.CodexCLI)

        transport_modules(codex_cli: ReqLlmNext.Transports.CodexCLI)
      end
    end
  end
end
