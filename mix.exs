defmodule ReqLlmNext.MixProject do
  use Mix.Project

  def project do
    [
      app: :req_llm_next,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [
        ignore_modules: [
          Mix.Tasks.Llm,
          Mix.Tasks.ReqLlmNext.Gen
        ]
      ],
      dialyzer: [
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: [
        main: "ReqLlmNext",
        extras: ["README.md"]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.live": :test,
        "test.all": :test,
        "test.parity": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {ReqLlmNext.Application, []}
    ]
  end

  defp deps do
    [
      {:splode, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.19"},
      {:server_sent_events, "~> 0.2"},
      {:llm_db, github: "agentjido/llm_db", branch: "main"},
      {:zoi, "~> 0.12"},
      {:uniq, "~> 0.6"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "dialyzer",
        "credo --strict"
      ],
      q: ["quality"],
      test: ["test --exclude integration --exclude live --exclude slow"],
      "test.live": ["test --include live --exclude slow"],
      "test.all": ["test --include integration --include live --include slow"],
      "test.parity": ["test --only parity"]
    ]
  end
end
