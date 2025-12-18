defmodule ReqLlmNext.Fixtures do
  @moduledoc """
  Fixture system for ReqLlmNext streaming tests.

  Records raw SSE chunks at the Finch level for full pipeline replay.
  During replay, SSE decoding uses the same wire module as live requests,
  ensuring consistent behavior.

  - Controlled via REQ_LLM_NEXT_FIXTURES_MODE env var: "record" | "replay"
  - Files live under test/fixtures/
  - Format matches req_llm: request/response metadata + b64-encoded raw SSE chunks
  """

  alias ReqLlmNext.Wire.Resolver

  @root Path.expand("../../test/fixtures", __DIR__)

  @type mode :: :record | :replay

  @spec mode() :: mode()
  def mode do
    case System.get_env("REQ_LLM_NEXT_FIXTURES_MODE") do
      "record" -> :record
      _ -> :replay
    end
  end

  @spec path(LLMDB.Model.t(), String.t()) :: String.t()
  def path(%LLMDB.Model{} = model, fixture_name) do
    provider = Atom.to_string(model.provider)

    safe_model_id =
      model.id
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")

    safe_name =
      fixture_name
      |> Path.basename()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")

    Path.join([@root, provider, safe_model_id, "#{safe_name}.json"])
  end

  @doc """
  In replay mode with a fixture configured, returns a stream that replays
  raw SSE chunks through ServerSentEvents.parse/1 and the wire module.
  """
  @spec maybe_replay_stream(LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, Enumerable.t()} | :no_fixture
  def maybe_replay_stream(model, _prompt, opts) do
    case {mode(), Keyword.get(opts, :fixture)} do
      {:replay, fixture_name} when is_binary(fixture_name) ->
        fixture_path = path(model, fixture_name)
        wire_mod = Resolver.wire_module!(model)

        case File.read(fixture_path) do
          {:ok, contents} ->
            fixture = Jason.decode!(contents)
            stream = build_replay_stream(fixture, wire_mod)
            {:ok, stream}

          {:error, _} ->
            raise """
            Fixture not found: #{fixture_path}
            Run with REQ_LLM_NEXT_FIXTURES_MODE=record to create it.
            """
        end

      _ ->
        :no_fixture
    end
  end

  defp build_replay_stream(%{"chunks" => chunks}, wire_mod) do
    Stream.resource(
      fn -> {chunks, ""} end,
      fn
        {[], _buffer} ->
          {:halt, nil}

        {[b64_chunk | rest], buffer} ->
          raw_data = Base.decode64!(b64_chunk)
          new_buffer = buffer <> raw_data
          {events, remaining} = ServerSentEvents.parse(new_buffer)

          text_chunks =
            events
            |> Enum.flat_map(&wire_mod.decode_sse_event(&1, nil))
            |> Enum.reject(&is_nil/1)

          {text_chunks, {rest, remaining}}
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Create a recorder struct to capture Finch stream data.
  """
  def start_recorder(model, fixture_name, prompt, finch_request) do
    %{
      model: model,
      fixture_name: fixture_name,
      prompt: prompt,
      request: extract_request_info(finch_request),
      status: nil,
      headers: %{},
      chunks: [],
      captured_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp extract_request_info(%Finch.Request{} = req) do
    body_binary = req.body || ""
    scheme = to_string(req.scheme)
    url = "#{scheme}://#{req.host}:#{req.port}#{req.path}"

    %{
      "method" => to_string(req.method) |> String.upcase(),
      "url" => url,
      "headers" => redact_headers(req.headers),
      "body" => %{
        "b64" => Base.encode64(body_binary),
        "canonical_json" => safe_decode_json(body_binary)
      }
    }
  end

  defp redact_headers(headers) do
    headers
    |> Enum.map(fn {k, v} ->
      key = String.downcase(to_string(k))

      value =
        if key in ["authorization", "x-api-key"] do
          "[REDACTED]"
        else
          v
        end

      {key, value}
    end)
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Map.new()
  end

  defp safe_decode_json(binary) do
    case Jason.decode(binary) do
      {:ok, json} -> json
      {:error, _} -> nil
    end
  end

  def record_status(nil, _status), do: nil
  def record_status(recorder, status), do: %{recorder | status: status}

  def record_headers(nil, _headers), do: nil

  def record_headers(recorder, headers) do
    header_map =
      headers
      |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Map.new()

    %{recorder | headers: header_map}
  end

  def record_chunk(nil, _data), do: nil

  def record_chunk(recorder, data) do
    %{recorder | chunks: [Base.encode64(data) | recorder.chunks]}
  end

  def save_fixture(nil), do: :ok

  def save_fixture(recorder) do
    fixture_path = path(recorder.model, recorder.fixture_name)
    File.mkdir_p!(Path.dirname(fixture_path))

    fixture = %{
      "provider" => Atom.to_string(recorder.model.provider),
      "model_id" => recorder.model.id,
      "prompt" => recorder.prompt,
      "captured_at" => recorder.captured_at,
      "request" => recorder.request,
      "response" => %{
        "status" => recorder.status,
        "headers" => recorder.headers
      },
      "chunks" => Enum.reverse(recorder.chunks)
    }

    File.write!(fixture_path, Jason.encode!(fixture, pretty: true))
    :ok
  end
end
