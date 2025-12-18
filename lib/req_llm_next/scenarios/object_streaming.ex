defmodule ReqLlmNext.Scenarios.ObjectStreaming do
  @moduledoc """
  Object generation (streaming) scenario.

  Tests structured output generation with JSON schema enforcement.
  """

  use ReqLlmNext.Scenario,
    id: :object_streaming,
    name: "Object Streaming",
    description: "Streaming structured output with JSON schema"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model) do
    ModelHelpers.supports_streaming_object_generation?(model)
  end

  @impl true
  def run(model_spec, _model, opts) do
    schema = [
      name: [type: :string, required: true, doc: "Person's full name"],
      age: [type: :pos_integer, required: true, doc: "Person's age in years"],
      occupation: [type: :string, doc: "Person's job or profession"]
    ]

    fixture_opts = Keyword.merge(opts, fixture: fixture_name(id()), max_tokens: 200)

    case ReqLlmNext.stream_object(
           model_spec,
           "Generate a software engineer profile named Alice who is 28 years old.",
           schema,
           fixture_opts
         ) do
      {:ok, stream_resp} ->
        object = ReqLlmNext.StreamResponse.object(stream_resp)

        cond do
          not is_map(object) ->
            error(:invalid_object_type, [
              step("stream_object", :error, response: stream_resp, error: :invalid_object_type)
            ])

          not Map.has_key?(object, "name") ->
            error(:missing_name, [
              step("stream_object", :error, response: stream_resp, error: :missing_name)
            ])

          not Map.has_key?(object, "age") ->
            error(:missing_age, [
              step("stream_object", :error, response: stream_resp, error: :missing_age)
            ])

          not is_binary(object["name"]) or object["name"] == "" ->
            error(:invalid_name, [
              step("stream_object", :error, response: stream_resp, error: :invalid_name)
            ])

          true ->
            ok([step("stream_object", :ok, response: stream_resp)])
        end

      {:error, reason} ->
        error(reason, [step("stream_object", :error, error: reason)])
    end
  end
end
