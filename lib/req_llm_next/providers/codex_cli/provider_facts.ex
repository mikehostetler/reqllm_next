defmodule ReqLlmNext.ModelProfile.ProviderFacts.CodexCLI do
  @moduledoc """
  Codex CLI descriptive fact extraction.
  """

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted_patch()
  def extract(%LLMDB.Model{} = model) do
    %{
      structured_outputs_native?: true,
      chat_supported?: chat_supported?(model)
    }
  end

  defp chat_supported?(%LLMDB.Model{capabilities: nil}), do: true

  defp chat_supported?(%LLMDB.Model{} = model) do
    capabilities = model.capabilities || %{}
    outputs = get_in(model.modalities || %{}, [:output]) || []

    Map.get(capabilities, :chat, true) != false and (outputs == [] or :text in outputs)
  end
end
