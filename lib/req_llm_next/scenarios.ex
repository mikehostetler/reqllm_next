defmodule ReqLlmNext.Scenarios do
  @moduledoc """
  Registry of capability scenarios.

  Single source of truth for what we test and how.

  ## Usage

      # Get all registered scenarios
      ReqLlmNext.Scenarios.all()

      # Get scenarios applicable to a model
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      scenarios = ReqLlmNext.Scenarios.for_model(model)

      # Get scenario by ID
      basic = ReqLlmNext.Scenarios.get(:basic)

      # List all scenario IDs
      ReqLlmNext.Scenarios.ids()
      #=> [:basic, :streaming, :usage, :token_limit, ...]

  ## Configuration

  The default scenario list can be overridden via application config:

      config :req_llm_next, ReqLlmNext.Scenarios, [
        MyApp.Scenarios.Custom,
        ReqLlmNext.Scenarios.Basic
      ]
  """

  @default_modules [
    ReqLlmNext.Scenarios.Basic,
    ReqLlmNext.Scenarios.Streaming,
    ReqLlmNext.Scenarios.Usage,
    ReqLlmNext.Scenarios.TokenLimit,
    ReqLlmNext.Scenarios.MultiTurn,
    ReqLlmNext.Scenarios.ObjectStreaming,
    ReqLlmNext.Scenarios.ToolMulti,
    ReqLlmNext.Scenarios.ToolRoundTrip,
    ReqLlmNext.Scenarios.ToolNone,
    ReqLlmNext.Scenarios.ToolParallel,
    ReqLlmNext.Scenarios.Embedding,
    ReqLlmNext.Scenarios.Reasoning,
    ReqLlmNext.Scenarios.ImageInput
  ]

  @doc """
  All registered scenarios (configurable via :req_llm_next config).
  """
  @spec all() :: [module()]
  def all do
    Application.get_env(:req_llm_next, __MODULE__, @default_modules)
  end

  @doc """
  Scenarios applicable to a given model.

  Filters the scenario list based on each scenario's `applies?/1` predicate.
  """
  @spec for_model(LLMDB.Model.t()) :: [module()]
  def for_model(%LLMDB.Model{} = model) do
    all()
    |> Enum.filter(& &1.applies?(model))
  end

  @doc """
  Get scenario by ID.

  Returns `nil` if no scenario with that ID is registered.
  """
  @spec get(atom()) :: module() | nil
  def get(id) when is_atom(id) do
    Enum.find(all(), fn mod -> mod.id() == id end)
  end

  @doc """
  List all scenario IDs.
  """
  @spec ids() :: [atom()]
  def ids do
    Enum.map(all(), & &1.id())
  end

  @doc """
  Run all applicable scenarios for a model.

  Returns a list of result maps, each annotated with scenario metadata.
  """
  @spec run_for_model(String.t(), LLMDB.Model.t(), keyword()) :: [map()]
  def run_for_model(model_spec, %LLMDB.Model{} = model, opts \\ []) do
    for_model(model)
    |> Enum.map(fn scenario_mod ->
      result = scenario_mod.run(model_spec, model, opts)

      result
      |> Map.put(:scenario_id, scenario_mod.id())
      |> Map.put(:scenario_name, scenario_mod.name())
      |> Map.put(:model_spec, model_spec)
    end)
  end
end
