defmodule ReqLlmNext.Executor.StreamState do
  @moduledoc false

  alias ReqLlmNext.Fixtures

  defstruct [:buffer, :recorder, :wire_mod, :error]

  @type t :: %__MODULE__{
          buffer: binary(),
          recorder: map() | nil,
          wire_mod: module(),
          error: term() | nil
        }

  @type msg ::
          {:status, non_neg_integer()}
          | {:headers, list()}
          | {:data, binary()}
          | :done

  @type result ::
          {:cont, [String.t()], t()}
          | {:halt, t()}

  @spec new(map() | nil, module()) :: t()
  def new(recorder, wire_mod) do
    %__MODULE__{buffer: "", recorder: recorder, wire_mod: wire_mod, error: nil}
  end

  @spec handle_message(msg(), t()) :: result()
  def handle_message({:status, status}, %__MODULE__{} = state) when status != 200 do
    Fixtures.save_fixture(state.recorder)
    {:halt, %{state | error: {:http_error, status}}}
  end

  def handle_message({:status, status}, %__MODULE__{} = state) when status == 200 do
    new_recorder = Fixtures.record_status(state.recorder, status)
    {:cont, [], %{state | recorder: new_recorder}}
  end

  def handle_message({:headers, headers}, %__MODULE__{} = state) do
    new_recorder = Fixtures.record_headers(state.recorder, headers)
    {:cont, [], %{state | recorder: new_recorder}}
  end

  def handle_message({:data, data}, %__MODULE__{} = state) do
    new_recorder = Fixtures.record_chunk(state.recorder, data)
    new_buffer = state.buffer <> data
    {events, remaining} = ServerSentEvents.parse(new_buffer)

    chunks =
      events
      |> Enum.flat_map(&state.wire_mod.decode_sse_event(&1, nil))
      |> Enum.reject(&is_nil/1)

    new_state = %{state | buffer: remaining, recorder: new_recorder}

    {:cont, chunks, new_state}
  end

  def handle_message(:done, %__MODULE__{} = state) do
    Fixtures.save_fixture(state.recorder)
    {:halt, state}
  end

  @spec handle_timeout(t()) :: t()
  def handle_timeout(%__MODULE__{} = state) do
    Fixtures.save_fixture(state.recorder)
    %{state | error: :timeout}
  end
end
