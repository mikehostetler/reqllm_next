defmodule ReqLlmNext.Scenarios.ToolNone do
  @moduledoc """
  Tool avoidance scenario.

  Tests that the model does NOT call tools when the prompt doesn't warrant it.
  Tools are available but the model should respond with text instead.
  """

  use ReqLlmNext.Scenario,
    id: :tool_none,
    name: "Tool Avoidance",
    description: "No tool called when inappropriate"

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
          location: [type: :string, required: true, doc: "City name"]
        ],
        callback: fn _args -> {:ok, "Weather data"} end
      )
    ]

    fixture_opts =
      Keyword.merge(opts, fixture: "no_tool", max_tokens: 500, tools: tools)

    case ReqLlmNext.stream_text(
           model_spec,
           "Tell me a joke about cats",
           fixture_opts
         ) do
      {:ok, stream_resp} ->
        text = ReqLlmNext.StreamResponse.text(stream_resp)
        tool_calls = ReqLlmNext.StreamResponse.tool_calls(stream_resp)

        cond do
          not is_binary(text) or String.length(text) == 0 ->
            error(:empty_response, [
              step("stream_text", :error, response: stream_resp, error: :empty_response)
            ])

          tool_calls != [] and Enum.any?(tool_calls, & &1) ->
            error(:unexpected_tool_calls, [
              step("stream_text", :error, response: stream_resp, error: :unexpected_tool_calls)
            ])

          true ->
            ok([step("stream_text", :ok, response: stream_resp)])
        end

      {:error, reason} ->
        error(reason, [step("stream_text", :error, error: reason)])
    end
  end
end
