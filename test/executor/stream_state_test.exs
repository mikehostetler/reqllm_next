defmodule ReqLlmNext.Executor.StreamStateTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Executor.StreamState

  defmodule FakeWire do
    def decode_sse_event(%{data: "[DONE]"}, _model), do: [nil]
    def decode_sse_event(%{data: data}, _model), do: [data]
  end

  describe "new/2" do
    test "creates initial state with empty buffer" do
      state = StreamState.new(nil, FakeWire)

      assert state.buffer == ""
      assert state.recorder == nil
      assert state.wire_mod == FakeWire
      assert state.error == nil
    end

    test "accepts recorder" do
      recorder = %{some: :data}
      state = StreamState.new(recorder, FakeWire)

      assert state.recorder == recorder
    end
  end

  describe "handle_message/2 with :status" do
    test "status 200 continues with empty chunks" do
      state = StreamState.new(nil, FakeWire)

      {:cont, chunks, new_state} = StreamState.handle_message({:status, 200}, state)

      assert chunks == []
      assert new_state.error == nil
    end

    test "non-200 status halts with http_error" do
      state = StreamState.new(nil, FakeWire)

      {:halt, new_state} = StreamState.handle_message({:status, 500}, state)

      assert new_state.error == {:http_error, 500}
    end

    test "404 status halts with http_error" do
      state = StreamState.new(nil, FakeWire)

      {:halt, new_state} = StreamState.handle_message({:status, 404}, state)

      assert new_state.error == {:http_error, 404}
    end
  end

  describe "handle_message/2 with :headers" do
    test "headers continue with empty chunks" do
      state = StreamState.new(nil, FakeWire)
      headers = [{"content-type", "text/event-stream"}]

      {:cont, chunks, new_state} = StreamState.handle_message({:headers, headers}, state)

      assert chunks == []
      assert new_state.error == nil
    end
  end

  describe "handle_message/2 with :data" do
    test "complete SSE event returns decoded chunks" do
      state = StreamState.new(nil, FakeWire)
      data = "data: hello\n\n"

      {:cont, chunks, new_state} = StreamState.handle_message({:data, data}, state)

      assert chunks == ["hello"]
      assert new_state.buffer == ""
    end

    test "multiple events in one data message" do
      state = StreamState.new(nil, FakeWire)
      data = "data: foo\n\ndata: bar\n\n"

      {:cont, chunks, new_state} = StreamState.handle_message({:data, data}, state)

      assert chunks == ["foo", "bar"]
      assert new_state.buffer == ""
    end

    test "partial SSE event is buffered" do
      state = StreamState.new(nil, FakeWire)
      data = "data: incomplete"

      {:cont, chunks, new_state} = StreamState.handle_message({:data, data}, state)

      assert chunks == []
      assert new_state.buffer == "data: incomplete"
    end

    test "buffered data completes on next message" do
      state = StreamState.new(nil, FakeWire)

      {:cont, [], state} = StreamState.handle_message({:data, "data: hel"}, state)
      {:cont, chunks, state} = StreamState.handle_message({:data, "lo\n\n"}, state)

      assert chunks == ["hello"]
      assert state.buffer == ""
    end

    test "filters nil values from decoded events" do
      state = StreamState.new(nil, FakeWire)
      data = "data: [DONE]\n\n"

      {:cont, chunks, _state} = StreamState.handle_message({:data, data}, state)

      assert chunks == []
    end
  end

  describe "handle_message/2 with :done" do
    test "done halts without error" do
      state = StreamState.new(nil, FakeWire)

      {:halt, final_state} = StreamState.handle_message(:done, state)

      assert final_state.error == nil
    end
  end

  describe "handle_timeout/1" do
    test "sets timeout error" do
      state = StreamState.new(nil, FakeWire)

      new_state = StreamState.handle_timeout(state)

      assert new_state.error == :timeout
    end
  end

  describe "full stream lifecycle" do
    test "status -> headers -> data -> done" do
      state = StreamState.new(nil, FakeWire)

      {:cont, [], state} = StreamState.handle_message({:status, 200}, state)
      {:cont, [], state} = StreamState.handle_message({:headers, []}, state)
      {:cont, ["Hi"], state} = StreamState.handle_message({:data, "data: Hi\n\n"}, state)
      {:halt, final_state} = StreamState.handle_message(:done, state)

      assert final_state.error == nil
      assert final_state.buffer == ""
    end

    test "error status short-circuits stream" do
      state = StreamState.new(nil, FakeWire)

      {:halt, final_state} = StreamState.handle_message({:status, 401}, state)

      assert final_state.error == {:http_error, 401}
    end
  end
end
