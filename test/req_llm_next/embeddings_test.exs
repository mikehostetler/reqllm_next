defmodule ReqLlmNext.EmbeddingsTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Error

  describe "cosine_similarity/2" do
    test "returns 1.0 for identical vectors" do
      vec = [1.0, 2.0, 3.0]

      assert_in_delta ReqLlmNext.cosine_similarity(vec, vec), 1.0, 0.0001
    end

    test "returns 0.0 for orthogonal vectors" do
      vec1 = [1.0, 0.0]
      vec2 = [0.0, 1.0]

      assert_in_delta ReqLlmNext.cosine_similarity(vec1, vec2), 0.0, 0.0001
    end

    test "returns -1.0 for opposite vectors" do
      vec1 = [1.0, 0.0, 0.0]
      vec2 = [-1.0, 0.0, 0.0]

      assert_in_delta ReqLlmNext.cosine_similarity(vec1, vec2), -1.0, 0.0001
    end

    test "handles zero vector by returning 0.0" do
      vec1 = [1.0, 2.0, 3.0]
      vec2 = [0.0, 0.0, 0.0]

      assert ReqLlmNext.cosine_similarity(vec1, vec2) == 0.0
    end

    test "computes similarity for normalized vectors" do
      vec1 = [0.6, 0.8]
      vec2 = [0.8, 0.6]

      result = ReqLlmNext.cosine_similarity(vec1, vec2)
      assert_in_delta result, 0.96, 0.0001
    end

    test "works with negative values" do
      vec1 = [-1.0, 2.0, -3.0]
      vec2 = [1.0, -2.0, 3.0]

      assert_in_delta ReqLlmNext.cosine_similarity(vec1, vec2), -1.0, 0.0001
    end
  end

  describe "embedding_models/0" do
    test "returns list of embedding model specs" do
      models = ReqLlmNext.embedding_models()

      assert is_list(models)
    end

    test "all items are string model specs" do
      models = ReqLlmNext.embedding_models()

      Enum.each(models, fn model ->
        assert is_binary(model)
        assert String.contains?(model, ":")
      end)
    end
  end

  describe "embed/3 input validation" do
    test "returns error for empty string input" do
      assert {:error, %Error.Invalid.Parameter{}} =
               ReqLlmNext.embed("openai:text-embedding-3-small", "")
    end

    test "returns error for empty list input" do
      assert {:error, %Error.Invalid.Parameter{}} =
               ReqLlmNext.embed("openai:text-embedding-3-small", [])
    end

    test "returns error for list containing empty string" do
      assert {:error, %Error.Invalid.Parameter{}} =
               ReqLlmNext.embed("openai:text-embedding-3-small", ["hello", ""])
    end

    test "returns error for list with non-string items" do
      assert {:error, %Error.Invalid.Parameter{}} =
               ReqLlmNext.embed("openai:text-embedding-3-small", ["hello", 123])
    end
  end

  describe "embed/3 model validation" do
    test "raises for non-embedding model" do
      assert_raise Error.Invalid.Capability, ~r/does not support embeddings/, fn ->
        ReqLlmNext.embed!("openai:gpt-4o-mini", "Hello")
      end
    end

    test "raises for unsupported provider embeddings" do
      assert_raise Error.Invalid.Capability, ~r/does not support embeddings/, fn ->
        ReqLlmNext.embed!("anthropic:claude-sonnet-4-5", "Hello")
      end
    end
  end

  describe "embed!/3" do
    test "raises on error" do
      assert_raise Error.Invalid.Parameter, fn ->
        ReqLlmNext.embed!("openai:text-embedding-3-small", "")
      end
    end
  end
end
