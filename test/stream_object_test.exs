defmodule ReqLlmNext.StreamObjectTest do
  use ExUnit.Case, async: true

  @person_schema [
    name: [type: :string, required: true, doc: "Person's full name"],
    age: [type: :integer, required: true, doc: "Person's age in years"],
    occupation: [type: :string, doc: "Person's job or profession"]
  ]

  describe "stream_object/4 OpenAI" do
    test "gpt-4o-mini streaming object with JSON schema" do
      {:ok, resp} =
        ReqLlmNext.stream_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      chunks = Enum.to_list(resp.stream)
      assert chunks != []

      text_chunks = Enum.filter(chunks, &is_binary/1)
      json = Enum.join(text_chunks)
      {:ok, object} = Jason.decode(json)

      assert is_binary(object["name"])
      assert is_integer(object["age"])
      assert resp.model.provider == :openai
    end

    test "StreamResponse.object/1 helper" do
      {:ok, resp} =
        ReqLlmNext.stream_object(
          "openai:gpt-4o-mini",
          "Generate a software engineer profile",
          @person_schema,
          fixture: "person_object"
        )

      object = ReqLlmNext.StreamResponse.object(resp)

      assert is_map(object)
      assert Map.has_key?(object, "name")
      assert Map.has_key?(object, "age")
    end
  end
end
