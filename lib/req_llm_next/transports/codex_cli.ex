defmodule ReqLlmNext.Transports.CodexCLI do
  @moduledoc false

  alias ReqLlmNext.{Error, Fixtures, Telemetry}

  @default_timeout Application.compile_env(:req_llm_next, :stream_timeout, 30_000)

  @spec stream(
          module(),
          module(),
          module(),
          LLMDB.Model.t(),
          String.t() | ReqLlmNext.Context.t(),
          keyword()
        ) :: {:ok, Enumerable.t()} | {:error, term()}
  def stream(provider_mod, protocol_mod, wire_mod, model, prompt, opts) do
    Telemetry.span_provider_request(
      provider_request_metadata(provider_mod, model, opts, wire_mod, protocol_mod),
      fn ->
        with {:ok, request} <- wire_mod.build_request(provider_mod, model, prompt, opts),
             recorder = maybe_start_recorder(model, prompt, request, opts),
             {:ok, chunks} <- run_request(request, recorder, model, wire_mod, protocol_mod, opts) do
          {:ok, Stream.concat([chunks])}
        end
      end
    )
  end

  defp maybe_start_recorder(model, prompt, request, opts) do
    case {Fixtures.mode(), Keyword.get(opts, :fixture)} do
      {:record, fixture_name} when is_binary(fixture_name) ->
        Fixtures.start_recorder(
          model,
          fixture_name,
          prompt,
          request,
          execution_metadata(opts)
        )

      _other ->
        nil
    end
  end

  defp run_request(request, recorder, model, wire_mod, protocol_mod, opts) do
    timeout = Keyword.get(opts, :receive_timeout, @default_timeout)
    task = Task.async(fn -> System.cmd(request.executable, request.args, cmd_opts(request)) end)

    result =
      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, {output, exit_status}} ->
          decode_output(output, exit_status, recorder, model, wire_mod, protocol_mod)

        nil ->
          timeout_recorder =
            recorder |> Fixtures.record_status(504) |> Fixtures.record_headers([])

          Fixtures.save_fixture(timeout_recorder)

          {:error, Error.API.Request.exception(reason: "Codex CLI timed out after #{timeout}ms")}
      end

    cleanup(request.cleanup_paths)
    result
  end

  defp cmd_opts(request) do
    [
      cd: request.cwd,
      env: request.env,
      stderr_to_stdout: true
    ]
  end

  defp decode_output(output, exit_status, recorder, model, wire_mod, protocol_mod) do
    status = if(exit_status == 0, do: 200, else: 500)
    recorder = recorder |> Fixtures.record_status(status) |> Fixtures.record_headers([])

    {lines, recorder} =
      output
      |> String.split(~r/\r?\n/, trim: true)
      |> Enum.reduce({[], recorder}, fn line, {acc, current_recorder} ->
        {[line | acc], Fixtures.record_chunk(current_recorder, line)}
      end)

    Fixtures.save_fixture(recorder)

    chunks =
      lines
      |> Enum.reverse()
      |> Enum.flat_map(fn line -> wire_mod.decode_wire_event(%{data: line}) end)
      |> Enum.flat_map(&protocol_mod.decode_event(&1, model))
      |> Enum.reject(&is_nil/1)
      |> maybe_append_exit_error(exit_status, output)

    {:ok, chunks}
  end

  defp maybe_append_exit_error(chunks, 0, _output), do: chunks

  defp maybe_append_exit_error(chunks, exit_status, output) do
    if Enum.any?(chunks, &match?({:error, _}, &1)) do
      chunks
    else
      chunks ++
        [
          {:error,
           %{
             message: "Codex CLI exited with status #{exit_status}",
             type: "cli_error",
             exit_status: exit_status,
             output: truncated_output(output)
           }}
        ]
    end
  end

  defp truncated_output(output) when is_binary(output) do
    output
    |> String.trim()
    |> String.slice(0, 500)
  end

  defp cleanup(paths) do
    Enum.each(paths || [], fn path ->
      if File.dir?(path) do
        File.rm_rf(path)
      else
        File.rm(path)
      end
    end)
  end

  defp execution_metadata(opts) do
    %{
      surface_id: Keyword.get(opts, :_execution_surface_id),
      semantic_protocol: Keyword.get(opts, :_execution_semantic_protocol),
      wire_format: Keyword.get(opts, :_execution_wire_format),
      transport: Keyword.get(opts, :_execution_transport)
    }
  end

  defp provider_request_metadata(provider_mod, model, opts, wire_mod, protocol_mod) do
    Telemetry.provider_request_metadata(model.provider, model, opts, %{
      provider_module: inspect(provider_mod),
      wire_module: inspect(wire_mod),
      protocol_module: inspect(protocol_mod)
    })
  end
end
