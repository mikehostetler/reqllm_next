defmodule ReqLlmNext.Scenario do
  @moduledoc """
  Behaviour + helpers for capability scenarios.

  A scenario is a module that:
    * decides if it applies (predicate on %LLMDB.Model{})
    * runs one or more steps (LLM calls)
    * validates the overall outcome

  ## Usage

      defmodule ReqLlmNext.Scenarios.Basic do
        use ReqLlmNext.Scenario,
          id: :basic,
          name: "Basic Text",
          description: "Pipeline works at all for chat models"

        @impl true
        def applies?(model), do: model.capabilities[:chat] == true

        @impl true
        def run(model_spec, _model, opts) do
          case ReqLlmNext.generate_text(model_spec, "Hello!", opts) do
            {:ok, response} ->
              text = ReqLlmNext.Response.text(response)
              if is_binary(text) and String.length(text) > 0 do
                ok([step("generate_text", :ok, response: response)])
              else
                error(:empty_response, [step("generate_text", :error, error: :empty_response)])
              end
            {:error, reason} ->
              error(reason, [step("generate_text", :error, error: reason)])
          end
        end
      end

  ## Result Structure

  All scenarios return a result map:

      %{
        status: :ok | :error | :skipped,
        steps: [step_result()],
        error: nil | term()
      }

  Where each step_result is:

      %{
        name: String.t(),
        status: :ok | :error,
        request: term() | nil,
        response: term() | nil,
        error: term() | nil
      }
  """

  @type id :: atom()

  @type step_result :: %{
          name: String.t(),
          status: :ok | :error,
          request: term(),
          response: term() | nil,
          error: nil | term()
        }

  @type result :: %{
          status: :ok | :error | :skipped,
          steps: [step_result()],
          error: nil | term()
        }

  @doc "Whether this scenario applies to a given model"
  @callback applies?(LLMDB.Model.t()) :: boolean()

  @doc """
  Run the scenario. Returns a structured result with status and steps.

  The scenario should:
  1. Execute one or more LLM calls
  2. Validate the results
  3. Return ok/error/skipped with step details

  ## Parameters

    * `model_spec` - Model specification string (e.g., "openai:gpt-4o-mini")
    * `model` - Resolved LLMDB.Model struct
    * `opts` - Options keyword list, typically including `:fixture` for fixture naming
  """
  @callback run(model_spec :: String.t(), model :: LLMDB.Model.t(), opts :: keyword()) :: result()

  @doc """
  Generate deterministic fixture name from scenario id + optional step.

  ## Examples

      iex> ReqLlmNext.Scenario.fixture_name(:basic)
      "basic"

      iex> ReqLlmNext.Scenario.fixture_name(:tool_round_trip, "1")
      "tool_round_trip_1"

      iex> ReqLlmNext.Scenario.fixture_name(:tool_round_trip, :first)
      "tool_round_trip_first"
  """
  @spec fixture_name(atom(), nil | String.t() | atom()) :: String.t()
  def fixture_name(scenario_id, step \\ nil) when is_atom(scenario_id) do
    base = Atom.to_string(scenario_id)

    case step do
      nil -> base
      step when is_binary(step) -> "#{base}_#{step}"
      step when is_atom(step) -> "#{base}_#{Atom.to_string(step)}"
    end
  end

  @doc "Build a successful result"
  @spec ok([step_result()]) :: result()
  def ok(steps \\ []), do: %{status: :ok, steps: steps, error: nil}

  @doc "Build an error result"
  @spec error(term(), [step_result()]) :: result()
  def error(reason, steps \\ []), do: %{status: :error, steps: steps, error: reason}

  @doc "Build a skipped result"
  @spec skipped(term()) :: result()
  def skipped(reason \\ :not_applicable), do: %{status: :skipped, steps: [], error: reason}

  @doc "Build a step result map"
  @spec step(String.t(), :ok | :error, keyword()) :: step_result()
  def step(name, status, opts \\ []) do
    %{
      name: name,
      status: status,
      request: Keyword.get(opts, :request),
      response: Keyword.get(opts, :response),
      error: Keyword.get(opts, :error)
    }
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour ReqLlmNext.Scenario

      @scenario_id Keyword.fetch!(opts, :id)
      @scenario_name Keyword.fetch!(opts, :name)
      @scenario_description Keyword.get(opts, :description, "")

      def id, do: @scenario_id
      def name, do: @scenario_name
      def description, do: @scenario_description

      import ReqLlmNext.Scenario,
        only: [
          fixture_name: 1,
          fixture_name: 2,
          ok: 0,
          ok: 1,
          error: 1,
          error: 2,
          skipped: 0,
          skipped: 1,
          step: 2,
          step: 3
        ]
    end
  end
end
