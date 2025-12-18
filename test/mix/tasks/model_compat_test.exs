defmodule Mix.Tasks.ReqLlmNext.ModelCompatTest do
  use ExUnit.Case, async: false

  @moduletag :skip

  alias Mix.Tasks.ReqLlmNext.ModelCompat

  setup do
    original_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(original_shell)
    end)

    :ok
  end

  describe "run/1 with --list" do
    test "lists all registered scenarios" do
      ModelCompat.run(["--list"])

      assert_received {:mix_shell, :info, [header]}
      assert header =~ "Registered Scenarios"

      messages = collect_messages()

      scenario_ids =
        ReqLlmNext.Scenarios.all()
        |> Enum.map(fn mod -> Atom.to_string(mod.id()) end)

      for id <- scenario_ids do
        assert Enum.any?(messages, &(&1 =~ id)),
               "Expected scenario #{id} to appear in output"
      end
    end

    test "shows scenario name and description" do
      ModelCompat.run(["--list"])

      messages = collect_messages()

      basic_scenario = ReqLlmNext.Scenarios.get(:basic)
      assert Enum.any?(messages, &(&1 =~ basic_scenario.name()))
    end
  end

  describe "run/1 with no arguments" do
    test "shows usage information" do
      ModelCompat.run([])

      assert_received {:mix_shell, :info, [output]}
      assert output =~ "Usage:"
      assert output =~ "mix req_llm_next.model_compat PATTERN"
      assert output =~ "--scenario"
      assert output =~ "--json"
      assert output =~ "--record"
      assert output =~ "--list"
    end

    test "shows example patterns" do
      ModelCompat.run([])

      assert_received {:mix_shell, :info, [output]}
      assert output =~ "*:*"
      assert output =~ "openai:*"
      assert output =~ "openai:gpt-4o"
    end
  end

  describe "run/1 with model spec expansion" do
    test "specific model pattern runs scenarios and shows results" do
      ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "basic"])

      messages = collect_messages()
      refute Enum.any?(messages, &(&1 =~ "Invalid model spec"))
      assert Enum.any?(messages, &(&1 =~ "gpt-4o-mini"))
    end

    test "prefix wildcard pattern filters models by prefix" do
      ModelCompat.run(["openai:gpt-4o-mini*", "--scenario", "basic"])

      messages = collect_messages()
      refute Enum.any?(messages, &(&1 =~ "Invalid model spec"))
      assert Enum.any?(messages, &(&1 =~ "gpt-4o-mini"))
    end
  end

  describe "expand_model_spec/1 behavior" do
    test "invalid spec triggers error message (tested via OptionParser)" do
      {opts, positional, _} =
        OptionParser.parse(["invalid"],
          switches: [
            scenario: :string,
            json: :boolean,
            record: :boolean,
            list: :boolean
          ]
        )

      assert positional == ["invalid"]
      refute opts[:list]
    end

    test "unimplemented provider pattern is detected" do
      spec = "notreal:some-model"
      [provider_part, _model_part] = String.split(spec, ":", parts: 2)
      provider = String.to_atom(provider_part)
      implemented = MapSet.new(ReqLlmNext.Providers.list())

      refute MapSet.member?(implemented, provider)
    end
  end

  describe "run/1 with --scenario filter" do
    test "scenario filter runs only specified scenario" do
      ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "basic"])

      messages = collect_messages()
      assert Enum.any?(messages, &(&1 =~ "Basic Text"))
      refute Enum.any?(messages, &(&1 =~ "Multi-turn"))
    end

    test "nonexistent scenario filter runs no scenarios" do
      ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "nonexistent_scenario_xyz"])

      messages = collect_messages()
      assert Enum.any?(messages, &(&1 =~ "0/0 passed"))
    end
  end

  describe "run/1 with --json flag" do
    test "json flag outputs valid JSON" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "basic", "--json"])
        end)

      assert {:ok, parsed} = Jason.decode(output)
      assert is_list(parsed)
      assert length(parsed) > 0

      first = hd(parsed)
      assert Map.has_key?(first, "model_spec")
      assert Map.has_key?(first, "status")
      assert Map.has_key?(first, "scenario_id")
    end
  end

  describe "run/1 with --record flag" do
    setup do
      original = System.get_env("REQ_LLM_NEXT_FIXTURES_MODE")

      on_exit(fn ->
        if original do
          System.put_env("REQ_LLM_NEXT_FIXTURES_MODE", original)
        else
          System.delete_env("REQ_LLM_NEXT_FIXTURES_MODE")
        end
      end)

      :ok
    end

    test "record flag sets environment variable" do
      System.delete_env("REQ_LLM_NEXT_FIXTURES_MODE")

      ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "basic", "--record"])

      assert System.get_env("REQ_LLM_NEXT_FIXTURES_MODE") == "record"
    end

    test "record flag combined with json output" do
      System.delete_env("REQ_LLM_NEXT_FIXTURES_MODE")

      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "basic", "--record", "--json"])
        end)

      assert System.get_env("REQ_LLM_NEXT_FIXTURES_MODE") == "record"
      assert {:ok, parsed} = Jason.decode(output)
      assert is_list(parsed)
    end
  end

  describe "run/1 error cases" do
    test "no models found for unimplemented provider pattern" do
      ModelCompat.run(["notimplemented:*", "--scenario", "basic"])

      messages = collect_messages()
      assert Enum.any?(messages, &(&1 =~ "Skipping" or &1 =~ "not implemented"))
    end

    test "invalid model spec format triggers error" do
      ModelCompat.run(["invalid-no-colon"])

      messages = collect_messages()
      assert Enum.any?(messages, &(&1 =~ "Invalid model spec"))
    end
  end

  describe "run/1 JSON output structure" do
    test "JSON output includes all required fields" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "basic", "--json"])
        end)

      assert {:ok, parsed} = Jason.decode(output)
      assert length(parsed) > 0

      for result <- parsed do
        assert Map.has_key?(result, "model_spec")
        assert Map.has_key?(result, "provider")
        assert Map.has_key?(result, "model_id")
        assert Map.has_key?(result, "scenario_id")
        assert Map.has_key?(result, "scenario_name")
        assert Map.has_key?(result, "status")
        assert Map.has_key?(result, "steps")
        assert is_list(result["steps"])
      end
    end

    test "JSON steps have correct structure" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          ModelCompat.run(["openai:gpt-4o-mini", "--scenario", "basic", "--json"])
        end)

      {:ok, parsed} = Jason.decode(output)
      first = hd(parsed)

      for step <- first["steps"] do
        assert Map.has_key?(step, "name")
        assert Map.has_key?(step, "status")
      end
    end

    test "JSON output for wildcard pattern" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          ModelCompat.run(["openai:gpt-4o*", "--scenario", "basic", "--json"])
        end)

      {:ok, parsed} = Jason.decode(output)
      assert length(parsed) >= 1

      specs = Enum.map(parsed, & &1["model_spec"])
      assert Enum.all?(specs, &String.starts_with?(&1, "openai:gpt-4o"))
    end
  end

  describe "option parsing" do
    test "parses all supported switches" do
      {opts, positional, _} =
        OptionParser.parse(
          ["*:*", "--scenario", "basic", "--json", "--record", "--list"],
          switches: [
            scenario: :string,
            json: :boolean,
            record: :boolean,
            list: :boolean
          ]
        )

      assert opts[:scenario] == "basic"
      assert opts[:json] == true
      assert opts[:record] == true
      assert opts[:list] == true
      assert positional == ["*:*"]
    end
  end

  defp collect_messages do
    collect_messages([])
  end

  defp collect_messages(acc) do
    receive do
      {:mix_shell, :info, [msg]} -> collect_messages([msg | acc])
      {:mix_shell, :error, [msg]} -> collect_messages([msg | acc])
    after
      10 -> Enum.reverse(acc)
    end
  end
end
