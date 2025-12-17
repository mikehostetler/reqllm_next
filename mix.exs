defmodule ReqLlmNext.MixProject do
  use Mix.Project

  def project do
    [
      app: :req_llm_next,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ReqLlmNext.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:finch, "~> 0.19"},
      {:server_sent_events, "~> 0.2"},
      {:llm_db, github: "agentjido/llm_db", branch: "main"}
    ]
  end
end
