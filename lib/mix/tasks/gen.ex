defmodule Mix.Tasks.ReqLlmNext.Gen do
  @shortdoc "Generate text from any AI model (streaming)"

  @moduledoc """
  Generate text from any supported AI model with streaming output.

  ## Usage

      mix req_llm_next.gen "Your prompt here" [options]

  ## Options

      --model, -m MODEL       Model specification in format provider:model-name
                              Default: openai:gpt-4o-mini

      --system, -s SYSTEM     System prompt/message to set context for the AI

      --max-tokens TOKENS     Maximum number of tokens to generate

      --temperature, -t TEMP  Sampling temperature for randomness (0.0-2.0)

      --log-level, -l LEVEL   Output verbosity level:
                              quiet   - Only show generated content
                              normal  - Show model info and content (default)

  ## Examples

      mix req_llm_next.gen "Explain how neural networks work"

      mix req_llm_next.gen "Write a haiku" --model openai:gpt-4o

      mix llm "What is 2+2?" --log-level quiet

  """
  use Mix.Task

  @preferred_cli_env ["req_llm_next.gen": :dev, llm: :dev]

  @impl Mix.Task
  def run(args) do
    {opts, args_list, _} = parse_args(args)
    log_level = parse_log_level(Keyword.get(opts, :log_level))

    Application.ensure_all_started(:req_llm_next)

    case validate_prompt(args_list) do
      {:ok, prompt} ->
        model_spec = Keyword.get(opts, :model, "openai:gpt-4o-mini")
        execute_streaming(model_spec, prompt, opts, log_level)

      {:error, :no_prompt} ->
        IO.puts("Error: Prompt is required")
        IO.puts("\nUsage: mix req_llm_next.gen \"Your prompt here\" [options]")
        System.halt(1)
    end
  end

  defp execute_streaming(model_spec, prompt, opts, log_level) do
    show_banner(model_spec, prompt, log_level)

    generation_opts = build_opts(opts)
    start_time = System.monotonic_time(:millisecond)

    case ReqLlmNext.stream_text(model_spec, prompt, generation_opts) do
      {:ok, %{stream: stream}} ->
        accumulated =
          stream
          |> Enum.reduce("", fn chunk, acc ->
            IO.write(chunk)
            acc <> chunk
          end)

        IO.puts("")
        show_stats(accumulated, start_time, log_level)

      {:error, error} ->
        IO.puts("\nError: #{inspect(error)}")
        System.halt(1)
    end
  rescue
    error ->
      IO.puts("\nError: #{Exception.message(error)}")
      System.halt(1)
  end

  defp show_banner(model_spec, prompt, :quiet), do: :ok

  defp show_banner(model_spec, prompt, _log_level) do
    preview = String.slice(prompt, 0, 50)
    suffix = if String.length(prompt) > 50, do: "...", else: ""
    IO.puts("#{model_spec} → \"#{preview}#{suffix}\"\n")
  end

  defp show_stats(_text, _start_time, :quiet), do: :ok

  defp show_stats(text, start_time, _log_level) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    tokens = max(1, div(String.length(text), 4))
    IO.puts("\n#{elapsed}ms • ~#{tokens} tokens")
  end

  defp build_opts(opts) do
    []
    |> maybe_add(:system, Keyword.get(opts, :system))
    |> maybe_add(:max_tokens, Keyword.get(opts, :max_tokens))
    |> maybe_add(:temperature, Keyword.get(opts, :temperature))
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_args(args) do
    OptionParser.parse(args,
      switches: [
        model: :string,
        system: :string,
        max_tokens: :integer,
        temperature: :float,
        log_level: :string
      ],
      aliases: [
        m: :model,
        s: :system,
        t: :temperature,
        l: :log_level
      ]
    )
  end

  defp validate_prompt([prompt | _]) when is_binary(prompt) and prompt != "", do: {:ok, prompt}
  defp validate_prompt(_), do: {:error, :no_prompt}

  defp parse_log_level("quiet"), do: :quiet
  defp parse_log_level(_), do: :normal
end
