defmodule ReqLlmNext.Scenarios.Embedding do
  @moduledoc """
  Embedding generation scenario.

  Tests that embedding models return valid numeric vectors and that
  semantically similar texts produce similar embeddings.
  """

  use ReqLlmNext.Scenario,
    id: :embedding,
    name: "Embedding",
    description: "Vector embedding generation and semantic similarity"

  alias ReqLlmNext.ModelHelpers

  @impl true
  def applies?(model), do: ModelHelpers.embeddings?(model)

  @impl true
  def run(model_spec, _model, opts) do
    texts = [
      "Hello world",
      "Hello, world!",
      "Completely different text about cats and dogs playing in the park."
    ]

    fixture_opts = Keyword.merge(opts, fixture: fixture_name(id()))

    case ReqLlmNext.embed(model_spec, texts, fixture_opts) do
      {:ok, embeddings} when is_list(embeddings) and length(embeddings) == 3 ->
        [e1, e2, e3] = embeddings
        validate_embeddings(e1, e2, e3)

      {:ok, other} ->
        error({:unexpected_embedding_format, other}, [
          step("embed", :error, error: {:unexpected_embedding_format, other})
        ])

      {:error, reason} ->
        error(reason, [step("embed", :error, error: reason)])
    end
  end

  defp validate_embeddings(e1, e2, e3) do
    cond do
      not valid_embedding?(e1) ->
        error(:invalid_embedding_1, [step("embed", :error, error: :invalid_embedding_1)])

      not valid_embedding?(e2) ->
        error(:invalid_embedding_2, [step("embed", :error, error: :invalid_embedding_2)])

      not valid_embedding?(e3) ->
        error(:invalid_embedding_3, [step("embed", :error, error: :invalid_embedding_3)])

      length(e1) != length(e2) or length(e1) != length(e3) ->
        error(:dimension_mismatch, [step("embed", :error, error: :dimension_mismatch)])

      true ->
        sim_12 = cosine_similarity(e1, e2)
        sim_13 = cosine_similarity(e1, e3)
        sim_23 = cosine_similarity(e2, e3)

        if sim_12 > sim_13 and sim_12 > sim_23 do
          ok([
            step("embed", :ok,
              response: %{similarities: %{e1_e2: sim_12, e1_e3: sim_13, e2_e3: sim_23}}
            )
          ])
        else
          error(
            {:unexpected_similarity_ordering, %{e1_e2: sim_12, e1_e3: sim_13, e2_e3: sim_23}},
            [
              step("embed", :error,
                error:
                  {:unexpected_similarity_ordering,
                   %{e1_e2: sim_12, e1_e3: sim_13, e2_e3: sim_23}}
              )
            ]
          )
        end
    end
  end

  defp valid_embedding?(embedding) do
    is_list(embedding) and
      length(embedding) > 0 and
      Enum.all?(embedding, &is_number/1)
  end

  defp cosine_similarity(vec1, vec2) do
    dot_product = Enum.zip(vec1, vec2) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
    magnitude1 = :math.sqrt(Enum.reduce(vec1, 0.0, fn x, acc -> acc + x * x end))
    magnitude2 = :math.sqrt(Enum.reduce(vec2, 0.0, fn x, acc -> acc + x * x end))

    if magnitude1 == 0.0 or magnitude2 == 0.0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end
end
