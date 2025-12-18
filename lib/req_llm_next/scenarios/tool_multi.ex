defmodule ReqLlmNext.Scenarios.ToolMulti do
  @moduledoc """
  Multi-tool selection scenario.

  Tests that the model correctly selects the appropriate tool
  when presented with multiple options.
  """

  use ReqLlmNext.Scenario,
    id: :tool_multi,
    name: "Multi-tool Selection",
    description: "Correct tool chosen from multiple options"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.tools_enabled?(model)

  @impl true
  def run(model_spec, _model, opts) do
    tools = [
      ReqLlmNext.tool(
        name: "get_weather",
        description: "Get current weather information for a location",
        parameter_schema: [
          location: [type: :string, required: true, doc: "City name"],
          unit: [type: {:in, ["celsius", "fahrenheit"]}, doc: "Temperature unit"]
        ],
        callback: fn _args -> {:ok, "Weather data"} end
      ),
      ReqLlmNext.tool(
        name: "tell_joke",
        description: "Tell a funny joke",
        parameter_schema: [
          topic: [type: :string, doc: "Topic for the joke"]
        ],
        callback: fn _args -> {:ok, "Why did the cat cross the road?"} end
      ),
      ReqLlmNext.tool(
        name: "get_time",
        description: "Get the current time",
        parameter_schema: [],
        callback: fn _args -> {:ok, "12:00 PM"} end
      )
    ]

    fixture_opts =
      Keyword.merge(opts, fixture: "multi_tool", max_tokens: 500, tools: tools)

    case ReqLlmNext.stream_text(
           model_spec,
           "What's the weather like in Paris, France?",
           fixture_opts
         ) do
      {:ok, stream_resp} ->
        tool_calls = ReqLlmNext.StreamResponse.tool_calls(stream_resp)

        cond do
          not is_list(tool_calls) or length(tool_calls) == 0 ->
            error(:no_tool_calls, [
              step("stream_text", :error, response: stream_resp, error: :no_tool_calls)
            ])

          true ->
            weather_call =
              Enum.find(tool_calls, fn tc ->
                ReqLlmNext.ToolCall.name(tc) == "get_weather"
              end)

            if weather_call do
              args = ReqLlmNext.ToolCall.args_map(weather_call)

              if is_map(args) and Map.has_key?(args, "location") do
                ok([step("stream_text", :ok, response: stream_resp)])
              else
                error(:missing_location_arg, [
                  step("stream_text", :error, response: stream_resp, error: :missing_location_arg)
                ])
              end
            else
              error(:wrong_tool_called, [
                step("stream_text", :error, response: stream_resp, error: :wrong_tool_called)
              ])
            end
        end

      {:error, reason} ->
        error(reason, [step("stream_text", :error, error: reason)])
    end
  end
end
