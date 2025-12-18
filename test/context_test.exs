defmodule ReqLlmNext.ContextTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{Message, ContentPart}
  alias ReqLlmNext.ToolCall

  describe "new/1" do
    test "creates empty context by default" do
      ctx = Context.new()
      assert ctx.messages == []
    end

    test "creates context with messages" do
      msgs = [Context.user("Hello")]
      ctx = Context.new(msgs)
      assert length(ctx.messages) == 1
    end
  end

  describe "to_list/1" do
    test "returns underlying message list" do
      msg = Context.user("Test")
      ctx = Context.new([msg])
      assert Context.to_list(ctx) == [msg]
    end
  end

  describe "append/2" do
    test "appends single message" do
      ctx = Context.new([Context.user("First")])
      ctx = Context.append(ctx, Context.assistant("Second"))

      assert length(ctx.messages) == 2
      assert Enum.at(ctx.messages, 1).role == :assistant
    end

    test "appends list of messages" do
      ctx = Context.new([Context.user("First")])
      ctx = Context.append(ctx, [Context.assistant("A"), Context.user("B")])

      assert length(ctx.messages) == 3
    end
  end

  describe "prepend/1" do
    test "prepends message to front" do
      ctx = Context.new([Context.user("Second")])
      ctx = Context.prepend(ctx, Context.system("First"))

      assert length(ctx.messages) == 2
      assert hd(ctx.messages).role == :system
    end
  end

  describe "concat/2" do
    test "concatenates two contexts" do
      ctx1 = Context.new([Context.user("A")])
      ctx2 = Context.new([Context.assistant("B")])
      combined = Context.concat(ctx1, ctx2)

      assert length(combined.messages) == 2
    end
  end

  describe "normalize/2" do
    test "normalizes string to user message" do
      {:ok, ctx} = Context.normalize("Hello")

      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end

    test "normalizes message struct" do
      msg = Context.assistant("Hi")
      {:ok, ctx} = Context.normalize(msg)

      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :assistant
    end

    test "passes through context" do
      original = Context.new([Context.user("Test")])
      {:ok, ctx} = Context.normalize(original)

      assert ctx == original
    end

    test "adds system prompt if none exists" do
      {:ok, ctx} = Context.normalize("Hello", system_prompt: "Be helpful")

      assert length(ctx.messages) == 2
      assert hd(ctx.messages).role == :system
    end

    test "does not add system prompt if one exists" do
      msgs = [Context.system("Existing"), Context.user("Hello")]
      {:ok, ctx} = Context.normalize(msgs, system_prompt: "New system")

      system_msgs = Enum.filter(ctx.messages, &(&1.role == :system))
      assert length(system_msgs) == 1
    end

    test "normalizes list of messages" do
      msgs = [Context.system("System"), Context.user("User")]
      {:ok, ctx} = Context.normalize(msgs)

      assert length(ctx.messages) == 2
    end

    test "normalizes loose map with atom role" do
      {:ok, ctx} = Context.normalize(%{role: :user, content: "Hello"})

      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :user
    end

    test "normalizes loose map with string role" do
      {:ok, ctx} = Context.normalize(%{"role" => "assistant", "content" => "Hi"})

      assert length(ctx.messages) == 1
      assert hd(ctx.messages).role == :assistant
    end

    test "returns error for invalid input" do
      assert {:error, :invalid_prompt} = Context.normalize(123)
    end
  end

  describe "normalize!/2" do
    test "returns context on success" do
      ctx = Context.normalize!("Hello")
      assert %Context{} = ctx
    end

    test "raises on error" do
      assert_raise ArgumentError, ~r/Failed to normalize/, fn ->
        Context.normalize!(123)
      end
    end
  end

  describe "user/2" do
    test "creates user message from string" do
      msg = Context.user("Hello")
      assert msg.role == :user
      assert hd(msg.content).text == "Hello"
    end

    test "creates user message with metadata map" do
      msg = Context.user("Hello", %{source: "api"})
      assert msg.role == :user
      assert msg.metadata == %{source: "api"}
    end

    test "creates user message with metadata keyword" do
      msg = Context.user("Hello", metadata: %{source: "api"})
      assert msg.metadata == %{source: "api"}
    end

    test "creates user message from content parts" do
      parts = [ContentPart.text("Hello"), ContentPart.image_url("http://example.com/img.png")]
      msg = Context.user(parts)
      assert msg.role == :user
      assert length(msg.content) == 2
    end
  end

  describe "assistant/2" do
    test "creates assistant message from string" do
      msg = Context.assistant("Hi there")
      assert msg.role == :assistant
      assert hd(msg.content).text == "Hi there"
    end

    test "creates assistant message with empty string" do
      msg = Context.assistant()
      assert msg.role == :assistant
      assert hd(msg.content).text == ""
    end

    test "creates assistant message with tool calls" do
      tool_call = ToolCall.new("call_123", "get_weather", ~s({"location":"SF"}))
      msg = Context.assistant("", tool_calls: [tool_call])

      assert msg.role == :assistant
      assert length(msg.tool_calls) == 1
      assert hd(msg.tool_calls).id == "call_123"
    end

    test "creates assistant message with tuple tool calls" do
      msg = Context.assistant("Let me check", tool_calls: [{"get_weather", %{location: "SF"}}])

      assert msg.role == :assistant
      assert length(msg.tool_calls) == 1
      assert ToolCall.name(hd(msg.tool_calls)) == "get_weather"
    end

    test "creates assistant message with map tool calls" do
      msg = Context.assistant("", tool_calls: [%{name: "get_time", arguments: "{}"}])

      assert msg.role == :assistant
      assert length(msg.tool_calls) == 1
    end
  end

  describe "system/2" do
    test "creates system message from string" do
      msg = Context.system("You are helpful")
      assert msg.role == :system
      assert hd(msg.content).text == "You are helpful"
    end

    test "creates system message with metadata" do
      msg = Context.system("You are helpful", %{version: 1})
      assert msg.metadata == %{version: 1}
    end
  end

  describe "tool_result/2 and tool_result/3" do
    test "creates tool result message with id and content" do
      msg = Context.tool_result("call_123", "Result data")
      assert msg.role == :tool
      assert msg.tool_call_id == "call_123"
      assert hd(msg.content).text == "Result data"
    end

    test "creates tool result message with id, name, and content" do
      msg = Context.tool_result("call_123", "get_weather", "Sunny")
      assert msg.role == :tool
      assert msg.tool_call_id == "call_123"
      assert msg.name == "get_weather"
    end
  end

  describe "tool_result_message/4" do
    test "creates tool result message with all fields" do
      msg = Context.tool_result_message("get_weather", "call_123", "Sunny", %{cached: true})
      assert msg.role == :tool
      assert msg.name == "get_weather"
      assert msg.tool_call_id == "call_123"
      assert msg.metadata == %{cached: true}
    end

    test "encodes non-string output as JSON" do
      msg = Context.tool_result_message("get_weather", "call_123", %{temp: 72})
      assert hd(msg.content).text == ~s({"temp":72})
    end
  end

  describe "text/3" do
    test "creates text message for any role" do
      msg = Context.text(:user, "Hello")
      assert msg.role == :user
      assert hd(msg.content).type == :text
    end

    test "includes metadata" do
      msg = Context.text(:user, "Hello", %{source: "test"})
      assert msg.metadata == %{source: "test"}
    end
  end

  describe "with_image/4" do
    test "creates message with text and image URL" do
      msg = Context.with_image(:user, "Check this", "http://example.com/img.png")
      assert msg.role == :user
      assert length(msg.content) == 2
      assert Enum.at(msg.content, 0).type == :text
      assert Enum.at(msg.content, 1).type == :image_url
    end
  end

  describe "build/3" do
    test "creates message from role and content parts" do
      parts = [ContentPart.text("Hello")]
      msg = Context.build(:user, parts)
      assert msg.role == :user
      assert msg.content == parts
    end
  end

  describe "validate/1" do
    test "validates valid context" do
      ctx = Context.new([Context.user("Hello")])
      assert {:ok, ^ctx} = Context.validate(ctx)
    end

    test "rejects multiple system messages" do
      ctx = Context.new([Context.system("A"), Context.system("B")])
      assert {:error, msg} = Context.validate(ctx)
      assert msg =~ "at most one system message"
    end

    test "rejects tool message without tool_call_id" do
      msg = %Message{role: :tool, content: [ContentPart.text("result")]}
      ctx = Context.new([msg])
      assert {:error, error_msg} = Context.validate(ctx)
      assert error_msg =~ "tool_call_id"
    end
  end

  describe "validate!/1" do
    test "returns context on success" do
      ctx = Context.new([Context.user("Hello")])
      assert ^ctx = Context.validate!(ctx)
    end

    test "raises on invalid context" do
      ctx = Context.new([Context.system("A"), Context.system("B")])

      assert_raise ArgumentError, ~r/Invalid context/, fn ->
        Context.validate!(ctx)
      end
    end
  end

  describe "Enumerable" do
    test "count/1 returns message count" do
      ctx = Context.new([Context.user("A"), Context.user("B")])
      assert Enum.count(ctx) == 2
    end

    test "member?/2 checks membership" do
      msg = Context.user("Test")
      ctx = Context.new([msg])
      assert Enum.member?(ctx, msg)
    end

    test "reduce works for iteration" do
      ctx = Context.new([Context.user("A"), Context.assistant("B")])
      roles = Enum.map(ctx, & &1.role)
      assert roles == [:user, :assistant]
    end

    test "filter works" do
      ctx = Context.new([Context.system("S"), Context.user("U"), Context.assistant("A")])
      user_msgs = Enum.filter(ctx, &(&1.role == :user))
      assert length(user_msgs) == 1
    end
  end

  describe "Collectable" do
    test "collects messages into context" do
      ctx = Context.new([Context.user("First")])

      new_msgs = [Context.assistant("Second"), Context.user("Third")]
      result = Enum.into(new_msgs, ctx)

      assert length(result.messages) == 3
    end
  end

  describe "Inspect" do
    test "inspects small context" do
      ctx = Context.new([Context.user("Hello")])
      result = inspect(ctx)
      assert result =~ "#Context<"
      assert result =~ "1"
      assert result =~ "user"
    end

    test "inspects larger context" do
      ctx =
        Context.new([
          Context.system("System"),
          Context.user("User 1"),
          Context.assistant("Assistant"),
          Context.user("User 2")
        ])

      result = inspect(ctx)
      assert result =~ "#Context<"
      assert result =~ "4"
    end
  end

  describe "ContentPart" do
    test "text/1 creates text content part" do
      part = ContentPart.text("Hello")
      assert part.type == :text
      assert part.text == "Hello"
    end

    test "text/2 creates text content part with metadata" do
      part = ContentPart.text("Hello", %{lang: "en"})
      assert part.metadata == %{lang: "en"}
    end

    test "thinking/1 creates thinking content part" do
      part = ContentPart.thinking("Let me think...")
      assert part.type == :thinking
      assert part.text == "Let me think..."
    end

    test "image_url/1 creates image URL content part" do
      part = ContentPart.image_url("https://example.com/img.png")
      assert part.type == :image_url
      assert part.url == "https://example.com/img.png"
    end

    test "image/2 creates binary image content part" do
      part = ContentPart.image(<<1, 2, 3>>, "image/jpeg")
      assert part.type == :image
      assert part.data == <<1, 2, 3>>
      assert part.media_type == "image/jpeg"
    end

    test "file/3 creates file content part" do
      part = ContentPart.file(<<1, 2, 3>>, "doc.pdf", "application/pdf")
      assert part.type == :file
      assert part.filename == "doc.pdf"
      assert part.media_type == "application/pdf"
    end

    test "valid?/1 returns true for valid part" do
      assert ContentPart.valid?(ContentPart.text("Hi"))
    end
  end

  describe "Message" do
    test "valid?/1 returns true for valid message" do
      msg = %Message{role: :user, content: [ContentPart.text("Hi")]}
      assert Message.valid?(msg)
    end

    test "valid?/1 returns false for invalid message" do
      refute Message.valid?(%{not: :a_message})
    end

    test "inspect shows role and content types" do
      msg = Context.user("Hello")
      result = inspect(msg)
      assert result =~ "#Message<"
      assert result =~ "user"
      assert result =~ "text"
    end
  end

  describe "ToolCall" do
    test "new/3 creates tool call with id" do
      tc = ToolCall.new("call_123", "get_weather", ~s({"location":"SF"}))
      assert tc.id == "call_123"
      assert tc.type == "function"
      assert tc.function.name == "get_weather"
      assert tc.function.arguments == ~s({"location":"SF"})
    end

    test "new/3 generates id when nil" do
      tc = ToolCall.new(nil, "get_time", "{}")
      assert tc.id =~ "call_"
    end

    test "name/1 extracts function name" do
      tc = ToolCall.new("call_1", "my_func", "{}")
      assert ToolCall.name(tc) == "my_func"
    end

    test "args_json/1 extracts arguments JSON" do
      tc = ToolCall.new("call_1", "func", ~s({"a":1}))
      assert ToolCall.args_json(tc) == ~s({"a":1})
    end

    test "args_map/1 decodes arguments" do
      tc = ToolCall.new("call_1", "func", ~s({"a":1}))
      assert ToolCall.args_map(tc) == %{"a" => 1}
    end

    test "args_map/1 returns nil for invalid JSON" do
      tc = ToolCall.new("call_1", "func", "not json")
      assert ToolCall.args_map(tc) == nil
    end

    test "matches_name?/2 checks function name" do
      tc = ToolCall.new("call_1", "get_weather", "{}")
      assert ToolCall.matches_name?(tc, "get_weather")
      refute ToolCall.matches_name?(tc, "other")
    end

    test "find_args/2 finds and decodes matching tool call" do
      calls = [
        ToolCall.new("call_1", "get_weather", ~s({"location":"SF"})),
        ToolCall.new("call_2", "get_time", "{}")
      ]

      assert ToolCall.find_args(calls, "get_weather") == %{"location" => "SF"}
      assert ToolCall.find_args(calls, "get_time") == %{}
      assert ToolCall.find_args(calls, "unknown") == nil
    end

    test "inspect shows id, name, and args" do
      tc = ToolCall.new("call_123", "get_weather", ~s({"location":"SF"}))
      result = inspect(tc)
      assert result =~ "#ToolCall<"
      assert result =~ "call_123"
      assert result =~ "get_weather"
    end
  end
end
