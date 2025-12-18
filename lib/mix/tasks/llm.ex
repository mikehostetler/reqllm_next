defmodule Mix.Tasks.Llm do
  @shortdoc "Alias for mix req_llm_next.gen"
  @moduledoc "Alias for `mix req_llm_next.gen`. See that task for documentation."

  alias Mix.Tasks.ReqLlmNext.Gen

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Gen.run(args)
end
