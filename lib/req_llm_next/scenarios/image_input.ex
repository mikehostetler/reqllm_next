defmodule ReqLlmNext.Scenarios.ImageInput do
  @moduledoc """
  Image input modality scenario.

  Tests that models with image input capability can receive and process images.
  Uses a simple test image with known content for validation.
  """

  use ReqLlmNext.Scenario,
    id: :image_input,
    name: "Image Input",
    description: "Image to text processing"

  alias ReqLlmNext.ModelHelpers
  alias ReqLlmNext.Context.ContentPart

  @impl true
  def applies?(model), do: ModelHelpers.supports_image_input?(model)

  @impl true
  def run(model_spec, _model, opts) do
    image_url =
      "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg"

    context =
      ReqLlmNext.context([
        ReqLlmNext.Context.user([
          ContentPart.text(
            "What animal is shown in this image? Answer with just the animal name."
          ),
          ContentPart.image_url(image_url)
        ])
      ])

    fixture_opts = Keyword.merge(opts, fixture: fixture_name(id()), max_tokens: 100)

    case ReqLlmNext.generate_text(model_spec, context, fixture_opts) do
      {:ok, response} ->
        text = ReqLlmNext.Response.text(response) || ""
        normalized = text |> String.downcase() |> String.trim()

        cond do
          String.length(text) == 0 ->
            error(:empty_response, [
              step("image_describe", :error, response: response, error: :empty_response)
            ])

          String.contains?(normalized, "ant") ->
            ok([step("image_describe", :ok, response: response)])

          String.contains?(normalized, "insect") ->
            ok([step("image_describe", :ok, response: response)])

          true ->
            error({:unexpected_description, text}, [
              step("image_describe", :error,
                response: response,
                error: {:unexpected_description, text}
              )
            ])
        end

      {:error, reason} ->
        error(reason, [step("image_describe", :error, error: reason)])
    end
  end
end
