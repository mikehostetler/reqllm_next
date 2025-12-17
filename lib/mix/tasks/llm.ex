defmodule Mix.Tasks.Llm do
  @shortdoc "Alias for mix req_llm_next.gen"
  @moduledoc "Alias for `mix req_llm_next.gen`. See that task for documentation."

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Mix.Tasks.ReqLlmNext.Gen.run(args)
end
