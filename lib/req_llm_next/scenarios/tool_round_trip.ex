defmodule ReqLlmNext.Scenarios.ToolRoundTrip do
  @moduledoc """
  Tool execution round trip scenario.

  Tests full tool calling flow:
  1. Model calls tool
  2. Tool result is appended to context
  3. Model generates final response using tool result
  """

  use ReqLlmNext.Scenario,
    id: :tool_round_trip,
    name: "Tool Round Trip",
    description: "Full tool execution flow with result integration"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.tools_enabled?(model)

  @impl true
  def run(model_spec, _model, opts) do
    tools = [
      ReqLlmNext.tool(
        name: "add",
        description: "Add two integers",
        parameter_schema: [
          a: [type: :integer, required: true, doc: "First number"],
          b: [type: :integer, required: true, doc: "Second number"]
        ],
        callback: fn %{a: a, b: b} -> {:ok, a + b} end
      )
    ]

    prompt =
      "Use the add tool to compute 2 + 3. After the tool result arrives, respond with 'sum=<value>'."

    step1_opts =
      Keyword.merge(opts,
        fixture: fixture_name(id(), "1"),
        max_tokens: 500,
        tools: tools,
        tool_choice: %{type: "tool", name: "add"}
      )

    with {:ok, resp1} <- ReqLlmNext.stream_text(model_spec, prompt, step1_opts),
         tool_calls when tool_calls != [] <- ReqLlmNext.StreamResponse.tool_calls(resp1) do
      ctx_with_assistant =
        ReqLlmNext.context([
          ReqLlmNext.Context.user(prompt),
          ReqLlmNext.Context.assistant("", tool_calls: tool_calls)
        ])

      ctx2 = ReqLlmNext.Context.execute_and_append_tools(ctx_with_assistant, tool_calls, tools)

      step2_opts = Keyword.merge(opts, fixture: fixture_name(id(), "2"), max_tokens: 500)

      case ReqLlmNext.stream_text(model_spec, ctx2, step2_opts) do
        {:ok, resp2} ->
          text = ReqLlmNext.StreamResponse.text(resp2)
          tool_calls2 = ReqLlmNext.StreamResponse.tool_calls(resp2)

          cond do
            text == "" ->
              error(:empty_final_response, [
                step("tool_call", :ok, response: resp1),
                step("final_response", :error, response: resp2, error: :empty_final_response)
              ])

            not String.contains?(text, "5") ->
              error(:result_not_in_response, [
                step("tool_call", :ok, response: resp1),
                step("final_response", :error,
                  response: resp2,
                  error: {:result_not_in_response, text}
                )
              ])

            tool_calls2 != [] ->
              error(:unexpected_tool_calls, [
                step("tool_call", :ok, response: resp1),
                step("final_response", :error, response: resp2, error: :unexpected_tool_calls)
              ])

            true ->
              ok([
                step("tool_call", :ok, response: resp1),
                step("final_response", :ok, response: resp2)
              ])
          end

        {:error, reason} ->
          error(reason, [
            step("tool_call", :ok, response: resp1),
            step("final_response", :error, error: reason)
          ])
      end
    else
      [] ->
        error(:no_tool_calls, [step("tool_call", :error, error: :no_tool_calls)])

      {:error, reason} ->
        error(reason, [step("tool_call", :error, error: reason)])
    end
  end
end
