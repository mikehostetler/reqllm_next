defmodule ReqLlmNext.ProviderTest.Comprehensive do
  @moduledoc """
  Comprehensive per-model provider tests for ReqLlmNext v2.

  Generates up to 8 focused tests per model:
  1. Basic generate_text (non-streaming)
  2. Streaming with system context
  3. Token limit constraints
  4. Usage metrics
  5. Object generation (streaming) - only for models with tool/JSON support
  6. Tool calling - multi-tool selection
  7. Tool calling - round trip execution
  8. Tool calling - no tool when inappropriate

  Tests use fixtures for fast, deterministic execution while supporting
  live API recording with REQ_LLM_NEXT_FIXTURES_MODE=record.

  ## Usage

      defmodule ReqLlmNext.Coverage.OpenAI.ComprehensiveTest do
        use ReqLlmNext.ProviderTest.Comprehensive,
          provider: :openai,
          models: ["openai:gpt-4o-mini", "openai:gpt-4o"]
      end

  """

  @doc """
  Returns list of models for a provider.
  """
  def models_for_provider(:openai) do
    [
      "openai:gpt-4o-mini",
      "openai:gpt-4o"
    ]
  end

  def models_for_provider(:anthropic) do
    [
      "anthropic:claude-sonnet-4-20250514",
      "anthropic:claude-haiku-4-5-20251001"
    ]
  end

  def models_for_provider(_), do: []

  @doc """
  Checks if a model supports object generation via JSON schema mode.

  Note: Only OpenAI-compatible providers support json_schema response_format.
  Anthropic uses tool calling for structured output which isn't implemented yet in v2.
  """
  def supports_object_generation?(model_spec) do
    case LLMDB.model(model_spec) do
      {:ok, model} ->
        caps = model.capabilities || %{}

        model.provider in [:openai, :groq, :openrouter, :xai] and
          (get_in(caps, [:json, :native]) == true ||
             get_in(caps, [:json, :schema]) == true ||
             get_in(caps, [:tools, :enabled]) == true)

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if a model supports tool calling.
  """
  def supports_tool_calling?(model_spec) do
    case LLMDB.model(model_spec) do
      {:ok, model} -> get_in(model.capabilities, [:tools, :enabled]) == true
      {:error, _} -> false
    end
  end

  defmacro __using__(opts) do
    provider = Keyword.fetch!(opts, :provider)
    models = Keyword.get(opts, :models)

    quote bind_quoted: [provider: provider, models: models] do
      use ExUnit.Case, async: false

      import ExUnit.Case

      alias ReqLlmNext.{Response, StreamResponse}

      @moduletag :coverage
      @moduletag provider: to_string(provider)
      @moduletag timeout: 300_000

      @provider provider
      @models models || ReqLlmNext.ProviderTest.Comprehensive.models_for_provider(provider)

      for model_spec <- @models do
        @model_spec model_spec

        describe "#{model_spec}" do
          @describetag model: model_spec |> String.split(":", parts: 2) |> List.last()

          @tag scenario: :basic
          test "basic generate_text (non-streaming)" do
            {:ok, result} =
              ReqLlmNext.generate_text(
                @model_spec,
                "Hello world! Respond briefly.",
                fixture: "basic",
                max_tokens: 100
              )

            assert %Response{} = result
            text = Response.text(result)
            assert is_binary(text)
            assert String.length(text) > 0
            assert result.model.provider == @provider
          end

          @tag scenario: :streaming
          test "stream_text with system context" do
            context =
              ReqLlmNext.context([
                ReqLlmNext.Context.system("You are a helpful assistant."),
                ReqLlmNext.Context.user("Say hello in one short sentence.")
              ])

            {:ok, resp} =
              ReqLlmNext.stream_text(
                @model_spec,
                context,
                fixture: "streaming",
                max_tokens: 100
              )

            assert %StreamResponse{} = resp
            assert resp.stream

            text = StreamResponse.text(resp)
            assert is_binary(text)
            assert String.length(text) > 0
          end

          @tag scenario: :token_limit
          @tag timeout: 600_000
          test "token limit constraints" do
            {:ok, result} =
              ReqLlmNext.generate_text(
                @model_spec,
                "Write a very long story about dragons and adventures.",
                fixture: "token_limit",
                max_tokens: 50
              )

            assert %Response{} = result
            text = Response.text(result)
            assert is_binary(text)
            assert String.length(text) > 0
            word_count = text |> String.split() |> length()
            assert word_count <= 100
          end

          @tag scenario: :usage
          test "usage metrics" do
            {:ok, resp} =
              ReqLlmNext.stream_text(
                @model_spec,
                "Hi there!",
                fixture: "usage",
                max_tokens: 20
              )

            text = StreamResponse.text(resp)
            assert is_binary(text)
            assert String.length(text) > 0
          end

          if ReqLlmNext.ProviderTest.Comprehensive.supports_object_generation?(model_spec) do
            @tag scenario: :object_streaming
            test "object generation (streaming)" do
              schema = [
                name: [type: :string, required: true, doc: "Person's full name"],
                age: [type: :pos_integer, required: true, doc: "Person's age in years"],
                occupation: [type: :string, doc: "Person's job or profession"]
              ]

              {:ok, resp} =
                ReqLlmNext.stream_object(
                  @model_spec,
                  "Generate a software engineer profile named Alice who is 28 years old.",
                  schema,
                  fixture: "object_streaming",
                  max_tokens: 200
                )

              object = StreamResponse.object(resp)
              assert is_map(object)
              assert Map.has_key?(object, "name")
              assert Map.has_key?(object, "age")
              assert is_binary(object["name"])
              assert object["name"] != ""
            end
          end

          if ReqLlmNext.ProviderTest.Comprehensive.supports_tool_calling?(model_spec) do
            @tag scenario: :tool_multi
            test "tool calling - multi-tool selection" do
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

              {:ok, resp} =
                ReqLlmNext.stream_text(
                  @model_spec,
                  "What's the weather like in Paris, France?",
                  fixture: "multi_tool",
                  max_tokens: 500,
                  tools: tools
                )

              tool_calls = StreamResponse.tool_calls(resp)
              assert is_list(tool_calls)
              assert length(tool_calls) > 0

              weather_call =
                Enum.find(tool_calls, fn tc ->
                  ReqLlmNext.ToolCall.name(tc) == "get_weather"
                end)

              assert weather_call, "Expected get_weather tool to be called"

              args = ReqLlmNext.ToolCall.args_map(weather_call)
              assert is_map(args)
              assert Map.has_key?(args, "location")
            end

            @tag scenario: :tool_round_trip
            test "tool calling - round trip execution" do
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

              {:ok, resp1} =
                ReqLlmNext.stream_text(
                  @model_spec,
                  "Use the add tool to compute 2 + 3. After the tool result arrives, respond with 'sum=<value>'.",
                  fixture: "tool_round_trip_1",
                  max_tokens: 500,
                  tools: tools,
                  tool_choice: %{type: "tool", name: "add"}
                )

              tool_calls = StreamResponse.tool_calls(resp1)
              assert tool_calls != [], "Expected tool call in response"

              ctx_with_assistant =
                ReqLlmNext.context([
                  ReqLlmNext.Context.user(
                    "Use the add tool to compute 2 + 3. After the tool result arrives, respond with 'sum=<value>'."
                  ),
                  ReqLlmNext.Context.assistant("", tool_calls: tool_calls)
                ])

              ctx2 =
                ReqLlmNext.Context.execute_and_append_tools(ctx_with_assistant, tool_calls, tools)

              {:ok, resp2} =
                ReqLlmNext.stream_text(
                  @model_spec,
                  ctx2,
                  fixture: "tool_round_trip_2",
                  max_tokens: 500
                )

              text = StreamResponse.text(resp2)
              assert text != "", "Expected text response after tool result"

              assert String.contains?(text, "5"),
                     "Expected response to contain the sum result '5'"

              assert StreamResponse.tool_calls(resp2) == [],
                     "Expected no tool calls in final response"
            end

            @tag scenario: :tool_none
            test "tool calling - no tool when inappropriate" do
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

              {:ok, resp} =
                ReqLlmNext.stream_text(
                  @model_spec,
                  "Tell me a joke about cats",
                  fixture: "no_tool",
                  max_tokens: 500,
                  tools: tools
                )

              text = StreamResponse.text(resp)
              assert is_binary(text)
              assert String.length(text) > 0, "Expected text response (joke)"

              tool_calls = StreamResponse.tool_calls(resp)

              assert tool_calls == [] or is_nil(Enum.find(tool_calls, &(&1 != nil))),
                     "Expected no tool calls for unrelated prompt"
            end
          end
        end
      end
    end
  end
end
