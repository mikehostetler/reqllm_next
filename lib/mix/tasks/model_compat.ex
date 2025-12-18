defmodule Mix.Tasks.ReqLlmNext.ModelCompat do
  @shortdoc "Validate model coverage with scenario-based testing"

  @moduledoc """
  Validate ReqLlmNext model coverage using the scenario system.

  Scenarios are capability tests that determine their own applicability based on
  model metadata from LLMDB. Each scenario runs one or more LLM calls and validates
  the results.

  ## Usage

      mix req_llm_next.model_compat                       # Show available scenarios
      mix req_llm_next.model_compat "*:*"                 # Run all scenarios for all models
      mix req_llm_next.model_compat "anthropic:*"         # Run for all Anthropic models
      mix req_llm_next.model_compat "openai:gpt-4o"       # Run for specific model
      mix req_llm_next.model_compat "openai:gpt-4o" --scenario basic  # Specific scenario
      mix req_llm_next.model_compat "*:*" --json          # JSON output for CI

  ## Flags

      --scenario ID       Run only the specified scenario (e.g., basic, streaming)
      --json              Output results as JSON (for CI/automation)
      --record            Record new fixtures (sets REQ_LLM_NEXT_FIXTURES_MODE=record)
      --list              List all registered scenarios and exit

  ## Model Spec Patterns

      "*:*"               All models from all implemented providers
      "anthropic:*"       All Anthropic models
      "openai:gpt-4o"     Specific model
      "openai:gpt-4*"     All models starting with gpt-4

  ## Fixture Integration

  Scenarios use the fixture system for deterministic replay:

      # Record fixtures for a model
      mix req_llm_next.model_compat "openai:gpt-4o-mini" --record

      # Replay from fixtures (default)
      mix req_llm_next.model_compat "openai:gpt-4o-mini"

  Fixture files are stored at: test/fixtures/<provider>/<model_id>/<scenario>.json

  ## Examples

      # Record all OpenAI fixtures
      mix req_llm_next.model_compat "openai:*" --record

      # Run specific scenario for specific model
      mix req_llm_next.model_compat "anthropic:claude-sonnet-4-20250514" --scenario streaming

      # CI validation with JSON output
      mix req_llm_next.model_compat "*:*" --json
  """

  use Mix.Task

  alias ReqLlmNext.{Scenarios, Fixtures}

  @preferred_cli_env :test

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        switches: [
          scenario: :string,
          json: :boolean,
          record: :boolean,
          list: :boolean
        ]
      )

    Application.ensure_all_started(:req_llm_next)

    cond do
      opts[:list] ->
        list_scenarios()

      Enum.empty?(positional) ->
        show_usage()

      true ->
        model_spec = List.first(positional)
        run_coverage(model_spec, opts)
    end
  end

  defp list_scenarios do
    Mix.shell().info("\n#{header("Registered Scenarios")}\n")

    for scenario_mod <- Scenarios.all() do
      id_str = Atom.to_string(scenario_mod.id())
      name = scenario_mod.name()
      desc = scenario_mod.description()

      Mix.shell().info("  #{IO.ANSI.cyan()}#{id_str}#{IO.ANSI.reset()}")
      Mix.shell().info("    #{name}")

      if desc != "" do
        Mix.shell().info("    #{IO.ANSI.faint()}#{desc}#{IO.ANSI.reset()}")
      end

      Mix.shell().info("")
    end
  end

  defp show_usage do
    Mix.shell().info("""

    #{header("ReqLlmNext Model Compatibility")}

    Usage:
      mix req_llm_next.model_compat PATTERN [--scenario ID] [--json] [--record]
      mix req_llm_next.model_compat --list

    Examples:
      mix req_llm_next.model_compat "*:*"               # All models
      mix req_llm_next.model_compat "openai:*"          # All OpenAI models
      mix req_llm_next.model_compat "openai:gpt-4o"     # Specific model
      mix req_llm_next.model_compat --list              # Show scenarios

    Flags:
      --scenario ID   Run only specified scenario
      --json          Output as JSON
      --record        Record fixtures (live API calls)
      --list          List all scenarios
    """)
  end

  defp run_coverage(model_spec, opts) do
    if opts[:record] do
      System.put_env("REQ_LLM_NEXT_FIXTURES_MODE", "record")
    end

    models = expand_model_spec(model_spec)

    if Enum.empty?(models) do
      Mix.shell().error("No models found matching: #{model_spec}")
      System.halt(1)
    end

    scenario_filter = opts[:scenario]
    start_time = System.monotonic_time(:millisecond)

    results =
      for {provider, model_id} <- models,
          spec = "#{provider}:#{model_id}",
          {:ok, model} <- [resolve_model(spec)] do
        run_model_scenarios(spec, model, scenario_filter, opts)
      end
      |> List.flatten()

    elapsed_ms = System.monotonic_time(:millisecond) - start_time

    if opts[:json] do
      print_json(results)
    else
      print_results(results, elapsed_ms)
    end

    failed = Enum.count(results, &(&1.status == :error))
    if failed > 0, do: System.halt(1)
  end

  defp run_model_scenarios(spec, model, scenario_filter, _opts) do
    scenarios = filter_scenarios(model, scenario_filter)

    Enum.map(scenarios, fn scenario_mod ->
      result = run_scenario_safely(scenario_mod, spec, model)

      result
      |> Map.put(:model_spec, spec)
      |> Map.put(:provider, model.provider)
      |> Map.put(:model_id, model.id)
      |> Map.put(:scenario_id, scenario_mod.id())
      |> Map.put(:scenario_name, scenario_mod.name())
      |> Map.put(
        :fixture_path,
        Fixtures.path(model, ReqLlmNext.Scenario.fixture_name(scenario_mod.id()))
      )
    end)
  end

  defp run_scenario_safely(scenario_mod, spec, model) do
    scenario_mod.run(spec, model, [])
  rescue
    e in RuntimeError ->
      if String.contains?(Exception.message(e), "Fixture not found") do
        %{status: :skipped, steps: [], error: :fixture_missing}
      else
        %{status: :error, steps: [], error: {:exception, Exception.message(e)}}
      end

    e ->
      %{status: :error, steps: [], error: {:exception, Exception.message(e)}}
  end

  defp filter_scenarios(model, nil), do: Scenarios.for_model(model)

  defp filter_scenarios(model, id) do
    atom_id =
      try do
        String.to_existing_atom(id)
      rescue
        ArgumentError -> String.to_atom(id)
      end

    Scenarios.for_model(model)
    |> Enum.filter(&(&1.id() == atom_id))
  end

  defp expand_model_spec(spec) do
    implemented = MapSet.new(ReqLlmNext.Providers.list())

    cond do
      spec == "*:*" ->
        all_implemented_models(implemented)

      String.contains?(spec, ":") ->
        [provider_part, model_part] = String.split(spec, ":", parts: 2)
        provider = String.to_atom(provider_part)

        cond do
          not MapSet.member?(implemented, provider) ->
            Mix.shell().info(
              "  #{IO.ANSI.yellow()}Skipping #{provider_part}: provider not implemented#{IO.ANSI.reset()}"
            )

            []

          model_part == "*" ->
            models_for_provider(provider)

          String.ends_with?(model_part, "*") ->
            prefix = String.trim_trailing(model_part, "*")

            models_for_provider(provider)
            |> Enum.filter(fn {_p, id} -> String.starts_with?(id, prefix) end)

          true ->
            [{provider, model_part}]
        end

      true ->
        Mix.shell().error("Invalid model spec: #{spec}")
        []
    end
    |> Enum.sort()
  end

  defp all_implemented_models(implemented) do
    implemented
    |> Enum.flat_map(&models_for_provider/1)
    |> Enum.sort()
  end

  defp models_for_provider(provider) do
    LLMDB.models(provider)
    |> Enum.map(fn model -> {provider, model.id} end)
  end

  defp resolve_model(spec) do
    case LLMDB.model(spec) do
      {:ok, model} -> {:ok, model}
      {:error, _} = err -> err
    end
  end

  defp print_json(results) do
    serializable =
      Enum.map(results, fn result ->
        %{
          model_spec: result.model_spec,
          provider: to_string(result.provider),
          model_id: result.model_id,
          scenario_id: to_string(result.scenario_id),
          scenario_name: result.scenario_name,
          status: to_string(result.status),
          error: if(result.error, do: inspect(result.error)),
          steps:
            Enum.map(result.steps, fn step ->
              %{
                name: step.name,
                status: to_string(step.status),
                error: if(step.error, do: inspect(step.error))
              }
            end)
        }
      end)

    IO.puts(Jason.encode!(serializable, pretty: true))
  end

  defp print_results(results, elapsed_ms) do
    Mix.shell().info("\n#{header("Model Compatibility Results")}\n")

    results
    |> Enum.group_by(& &1.provider)
    |> Enum.sort_by(fn {provider, _} -> provider end)
    |> Enum.each(fn {provider, provider_results} ->
      Mix.shell().info(provider_header(provider))

      provider_results
      |> Enum.group_by(& &1.model_id)
      |> Enum.sort_by(fn {model_id, _} -> model_id end)
      |> Enum.each(fn {model_id, model_results} ->
        print_model_results(model_id, model_results)
      end)

      Mix.shell().info("")
    end)

    print_summary(results, elapsed_ms)
  end

  defp print_model_results(model_id, results) do
    has_failures = Enum.any?(results, &(&1.status == :error))
    all_skipped = Enum.all?(results, &(&1.status == :skipped))

    status_icon =
      cond do
        has_failures -> "#{IO.ANSI.red()}✗"
        all_skipped -> "#{IO.ANSI.yellow()}−"
        true -> "#{IO.ANSI.green()}✓"
      end

    Mix.shell().info("  #{status_icon} #{model_id}#{IO.ANSI.reset()}")

    for result <- results do
      print_scenario_result(result)
    end
  end

  defp print_scenario_result(result) do
    {icon, color} =
      case result.status do
        :ok -> {"✓", IO.ANSI.green()}
        :error -> {"✗", IO.ANSI.red()}
        :skipped -> {"−", IO.ANSI.yellow()}
      end

    Mix.shell().info("      #{color}#{icon} #{result.scenario_name}#{IO.ANSI.reset()}")

    if result.status == :error do
      Mix.shell().info(
        "        #{IO.ANSI.faint()}error: #{inspect(result.error)}#{IO.ANSI.reset()}"
      )

      for step <- result.steps, step.status == :error do
        Mix.shell().info(
          "        #{IO.ANSI.faint()}step #{step.name}: #{inspect(step.error)}#{IO.ANSI.reset()}"
        )
      end
    end
  end

  defp print_summary(results, elapsed_ms) do
    total = length(results)
    passed = Enum.count(results, &(&1.status == :ok))
    failed = Enum.count(results, &(&1.status == :error))
    skipped = Enum.count(results, &(&1.status == :skipped))

    elapsed_sec = Float.round(elapsed_ms / 1000, 1)

    color = if failed == 0, do: IO.ANSI.green(), else: IO.ANSI.red()
    pct = if total > 0, do: Float.round(passed / total * 100, 1), else: 0.0

    Mix.shell().info("#{header("Summary")}\n")

    Mix.shell().info(
      "#{color}#{passed}/#{total} passed (#{pct}%)#{IO.ANSI.reset()}" <>
        " • #{failed} failed • #{skipped} skipped • #{elapsed_sec}s\n"
    )
  end

  defp header(title) do
    "#{IO.ANSI.bright()}#{title}#{IO.ANSI.reset()}"
  end

  defp provider_header(provider) do
    "#{IO.ANSI.cyan()}#{IO.ANSI.bright()}#{provider}#{IO.ANSI.reset()}"
  end
end
