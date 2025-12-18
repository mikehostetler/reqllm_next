defmodule ReqLlmNext.Wire.OpenAIEmbeddingsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Wire.OpenAIEmbeddings

  describe "path/0" do
    test "returns embeddings endpoint" do
      assert OpenAIEmbeddings.path() == "/v1/embeddings"
    end
  end

  describe "encode_body/3" do
    test "encodes single text input" do
      model = embedding_model()
      input = "Hello world"

      body = OpenAIEmbeddings.encode_body(model, input, [])

      assert body == %{
               "model" => "text-embedding-3-small",
               "input" => "Hello world"
             }
    end

    test "encodes batch input" do
      model = embedding_model()
      input = ["Hello", "World"]

      body = OpenAIEmbeddings.encode_body(model, input, [])

      assert body == %{
               "model" => "text-embedding-3-small",
               "input" => ["Hello", "World"]
             }
    end

    test "includes optional dimensions" do
      model = embedding_model()
      input = "Hello"

      body = OpenAIEmbeddings.encode_body(model, input, dimensions: 256)

      assert body == %{
               "model" => "text-embedding-3-small",
               "input" => "Hello",
               "dimensions" => 256
             }
    end

    test "includes optional encoding_format" do
      model = embedding_model()
      input = "Hello"

      body = OpenAIEmbeddings.encode_body(model, input, encoding_format: "base64")

      assert body == %{
               "model" => "text-embedding-3-small",
               "input" => "Hello",
               "encoding_format" => "base64"
             }
    end

    test "includes all options together" do
      model = embedding_model()
      input = "Hello"

      body = OpenAIEmbeddings.encode_body(model, input, dimensions: 512, encoding_format: "float")

      assert body == %{
               "model" => "text-embedding-3-small",
               "input" => "Hello",
               "dimensions" => 512,
               "encoding_format" => "float"
             }
    end
  end

  describe "extract_embeddings/2" do
    test "extracts single embedding" do
      response = %{
        "data" => [
          %{"embedding" => [0.1, 0.2, 0.3], "index" => 0}
        ]
      }

      assert {:ok, [0.1, 0.2, 0.3]} = OpenAIEmbeddings.extract_embeddings(response, "Hello")
    end

    test "extracts batch embeddings in order" do
      response = %{
        "data" => [
          %{"embedding" => [0.3, 0.4], "index" => 1},
          %{"embedding" => [0.1, 0.2], "index" => 0}
        ]
      }

      assert {:ok, [[0.1, 0.2], [0.3, 0.4]]} =
               OpenAIEmbeddings.extract_embeddings(response, ["Hello", "World"])
    end

    test "returns error for invalid response format" do
      response = %{"error" => "something went wrong"}

      assert {:error, error} = OpenAIEmbeddings.extract_embeddings(response, "Hello")
      assert error.reason == "Invalid embedding response format"
    end

    test "returns error for missing data field" do
      response = %{}

      assert {:error, error} = OpenAIEmbeddings.extract_embeddings(response, "Hello")
      assert error.reason == "Invalid embedding response format"
    end
  end

  defp embedding_model do
    %LLMDB.Model{
      id: "text-embedding-3-small",
      provider: :openai,
      modalities: %{input: [:text], output: [:text, :embedding]},
      capabilities: %{
        embeddings: %{default_dimensions: 1536}
      },
      extra: %{type: "embedding"}
    }
  end
end
