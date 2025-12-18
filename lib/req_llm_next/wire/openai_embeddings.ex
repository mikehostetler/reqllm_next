defmodule ReqLlmNext.Wire.OpenAIEmbeddings do
  @moduledoc """
  Wire protocol for OpenAI Embeddings API.
  Handles /v1/embeddings endpoint.
  """

  alias ReqLlmNext.Error

  @spec path() :: String.t()
  def path, do: "/v1/embeddings"

  @spec encode_body(LLMDB.Model.t(), String.t() | [String.t()], keyword()) :: map()
  def encode_body(model, input, opts) do
    body = %{
      "model" => model.id,
      "input" => input
    }

    body =
      if dimensions = Keyword.get(opts, :dimensions) do
        Map.put(body, "dimensions", dimensions)
      else
        body
      end

    body =
      if encoding_format = Keyword.get(opts, :encoding_format) do
        Map.put(body, "encoding_format", encoding_format)
      else
        body
      end

    body
  end

  @spec extract_embeddings(map(), String.t() | [String.t()]) ::
          {:ok, [float()] | [[float()]]} | {:error, term()}
  def extract_embeddings(%{"data" => [%{"embedding" => embedding}]}, input)
      when is_binary(input) do
    {:ok, embedding}
  end

  def extract_embeddings(%{"data" => data}, input) when is_list(data) and is_list(input) do
    embeddings =
      data
      |> Enum.sort_by(& &1["index"])
      |> Enum.map(& &1["embedding"])

    {:ok, embeddings}
  end

  def extract_embeddings(response, _input) do
    {:error,
     Error.API.Response.exception(
       reason: "Invalid embedding response format",
       response_body: response
     )}
  end
end
