defmodule ReqLlmNext.Scenarios.ToolParallel do
  @moduledoc """
  Parallel tool calling scenario.

  Tests that models supporting parallel tool calls can emit multiple
  tool calls in a single turn when presented with independent tasks.
  """

  use ReqLlmNext.Scenario,
    id: :tool_parallel,
    name: "Parallel Tool Calls",
    description: "Multiple independent tool calls in single turn"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model) do
    ModelHelpers.tools_enabled?(model) and ModelHelpers.tools_parallel?(model)
  end

  @impl true
  def run(model_spec, _model, opts) do
    tools = [
      ReqLlmNext.tool(
        name: "get_weather",
        description: "Get current weather for a city",
        parameter_schema: [
          city: [type: :string, required: true, doc: "City name"]
        ],
        callback: fn _args -> {:ok, "Sunny, 22°C"} end
      ),
      ReqLlmNext.tool(
        name: "get_time",
        description: "Get current time for a city",
        parameter_schema: [
          city: [type: :string, required: true, doc: "City name"]
        ],
        callback: fn _args -> {:ok, "14:30 local time"} end
      )
    ]

    prompt = """
    I need both the weather AND the time for Paris.
    Use both get_weather and get_time tools for Paris.
    These are independent requests, so call both tools.
    """

    fixture_opts =
      Keyword.merge(opts, fixture: fixture_name(id()), max_tokens: 500, tools: tools)

    case ReqLlmNext.stream_text(model_spec, prompt, fixture_opts) do
      {:ok, stream_resp} ->
        tool_calls = ReqLlmNext.StreamResponse.tool_calls(stream_resp)
        validate_parallel_calls(stream_resp, tool_calls)

      {:error, reason} ->
        error(reason, [step("parallel_tools", :error, error: reason)])
    end
  end

  defp validate_parallel_calls(stream_resp, tool_calls) do
    cond do
      not is_list(tool_calls) or length(tool_calls) < 2 ->
        error({:expected_multiple_tool_calls, length(tool_calls || [])}, [
          step("parallel_tools", :error,
            response: stream_resp,
            error: {:expected_multiple_tool_calls, length(tool_calls || [])}
          )
        ])

      true ->
        tool_names = Enum.map(tool_calls, &ReqLlmNext.ToolCall.name/1) |> Enum.sort()

        if "get_time" in tool_names and "get_weather" in tool_names do
          ok([step("parallel_tools", :ok, response: stream_resp)])
        else
          error({:wrong_tools_called, tool_names}, [
            step("parallel_tools", :error,
              response: stream_resp,
              error: {:wrong_tools_called, tool_names}
            )
          ])
        end
    end
  end
end
