defmodule ReqLlmNext.Context.MessageTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Context.Message

  describe "schema/0" do
    test "returns a Zoi schema" do
      schema = Message.schema()
      assert is_struct(schema)
    end
  end

  describe "new/1" do
    test "creates a message with required fields" do
      assert {:ok, message} = Message.new(%{role: :user})

      assert message.role == :user
      assert message.content == []
      assert message.metadata == %{}
    end

    test "creates a message with all fields" do
      content = [ContentPart.text("Hello")]

      attrs = %{
        role: :assistant,
        content: content,
        name: "assistant-name",
        tool_call_id: "call-123",
        tool_calls: [%{id: "tc1", function: %{name: "test", arguments: "{}"}}],
        metadata: %{custom: "data"},
        reasoning_details: [%{"type" => "reasoning.text", "text" => "thinking..."}]
      }

      assert {:ok, message} = Message.new(attrs)

      assert message.role == :assistant
      assert message.content == content
      assert message.name == "assistant-name"
      assert message.tool_call_id == "call-123"
      assert message.tool_calls == [%{id: "tc1", function: %{name: "test", arguments: "{}"}}]
      assert message.metadata == %{custom: "data"}
      assert message.reasoning_details == [%{"type" => "reasoning.text", "text" => "thinking..."}]
    end

    test "returns error for string role (not coerced)" do
      assert {:error, _reason} = Message.new(%{role: "user"})
    end

    test "creates message with system role" do
      assert {:ok, message} =
               Message.new(%{role: :system, content: [ContentPart.text("You are helpful")]})

      assert message.role == :system
    end

    test "creates message with tool role" do
      assert {:ok, message} = Message.new(%{role: :tool, tool_call_id: "call-123"})
      assert message.role == :tool
      assert message.tool_call_id == "call-123"
    end

    test "returns error for invalid role" do
      assert {:error, _reason} = Message.new(%{role: :invalid_role})
    end

    test "returns error for missing role" do
      assert {:error, _reason} = Message.new(%{})
    end
  end

  describe "new!/1" do
    test "creates a message with valid attrs" do
      message = Message.new!(%{role: :user, content: [ContentPart.text("Hello")]})

      assert message.role == :user
      assert length(message.content) == 1
    end

    test "raises ArgumentError for invalid attrs" do
      assert_raise ArgumentError, ~r/Invalid message/, fn ->
        Message.new!(%{role: :invalid_role})
      end
    end

    test "raises ArgumentError for missing role" do
      assert_raise ArgumentError, ~r/Invalid message/, fn ->
        Message.new!(%{})
      end
    end
  end

  describe "valid?/1" do
    test "returns true for valid message with empty content" do
      {:ok, message} = Message.new(%{role: :user})
      assert Message.valid?(message)
    end

    test "returns true for valid message with content" do
      {:ok, message} = Message.new(%{role: :user, content: [ContentPart.text("Hello")]})
      assert Message.valid?(message)
    end

    test "returns true for all role types" do
      for role <- [:user, :assistant, :system, :tool] do
        {:ok, message} = Message.new(%{role: role})
        assert Message.valid?(message), "Expected #{role} message to be valid"
      end
    end

    test "returns false for non-message values" do
      refute Message.valid?(nil)
      refute Message.valid?("string")
      refute Message.valid?(%{role: :user})
      refute Message.valid?([])
    end

    test "returns false for message struct with non-list content" do
      message = %Message{role: :user, content: "not a list", metadata: %{}}
      refute Message.valid?(message)
    end
  end

  describe "Inspect protocol" do
    test "formats message with text content" do
      {:ok, message} = Message.new(%{role: :user, content: [ContentPart.text("Hello")]})

      result = inspect(message)

      assert result =~ "#Message<"
      assert result =~ ":user"
      assert result =~ "text"
      assert result =~ ">"
    end

    test "formats message with multiple content parts" do
      content = [
        ContentPart.text("What is this?"),
        ContentPart.image(<<0, 1, 2, 3>>, "image/png")
      ]

      {:ok, message} = Message.new(%{role: :user, content: content})

      result = inspect(message)

      assert result =~ "#Message<"
      assert result =~ ":user"
      assert result =~ "text"
      assert result =~ "image"
    end

    test "formats message with empty content" do
      {:ok, message} = Message.new(%{role: :assistant})

      result = inspect(message)

      assert result =~ "#Message<"
      assert result =~ ":assistant"
    end

    test "formats message with thinking content" do
      content = [ContentPart.thinking("step by step")]
      {:ok, message} = Message.new(%{role: :assistant, content: content})

      result = inspect(message)

      assert result =~ "thinking"
    end

    test "formats message with image_url content" do
      content = [ContentPart.image_url("https://example.com/image.png")]
      {:ok, message} = Message.new(%{role: :user, content: content})

      result = inspect(message)

      assert result =~ "image_url"
    end
  end

  describe "Jason.Encoder" do
    test "encodes message to JSON" do
      {:ok, message} = Message.new(%{role: :user, content: [ContentPart.text("Hello")]})

      assert {:ok, json} = Jason.encode(message)
      assert is_binary(json)
    end

    test "encoded JSON can be decoded" do
      {:ok, message} =
        Message.new(%{
          role: :user,
          content: [ContentPart.text("Hello")],
          metadata: %{"key" => "value"}
        })

      {:ok, json} = Jason.encode(message)
      {:ok, decoded} = Jason.decode(json)

      assert decoded["role"] == "user"
      assert decoded["metadata"] == %{"key" => "value"}
    end
  end
end
