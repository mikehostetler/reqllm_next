defmodule ReqLlmNext.Wire.CodexCLI do
  @moduledoc false

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{ContentPart, Message}
  alias ReqLlmNext.Error
  alias ReqLlmNext.Schema

  @provider_option_keys [:codex_env, :codex_executable, :codex_profile, :codex_working_dir]

  @spec build_request(module(), LLMDB.Model.t(), String.t() | Context.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def build_request(provider_mod, %LLMDB.Model{} = model, prompt, opts) do
    provider_options = provider_options(opts)

    with {:ok, executable} <- executable(provider_options),
         {:ok, prompt_text} <- prompt_text(prompt),
         {:ok, cwd, cleanup_paths} <- working_directory(provider_options),
         {:ok, schema_path, cleanup_paths} <- maybe_schema_path(opts, cleanup_paths),
         args <- args(model, prompt_text, provider_options, schema_path),
         env <- env(provider_mod, opts, provider_options) do
      {:ok,
       %{
         executable: executable,
         args: args,
         env: env,
         cwd: cwd,
         cleanup_paths: cleanup_paths,
         method: "EXEC",
         transport: "local_process",
         url: "codex://local/exec",
         headers: [],
         body: request_body(model, prompt_text, args, env, opts)
       }}
    end
  end

  @spec decode_wire_event(%{data: binary()} | map()) :: [term()]
  def decode_wire_event(%{data: data}) when is_binary(data) do
    case Jason.decode(String.trim(data)) do
      {:ok, decoded} when is_map(decoded) -> [decoded]
      {:ok, _decoded} -> []
      {:error, _decode_error} -> []
    end
  end

  def decode_wire_event(event) when is_map(event), do: [event]
  def decode_wire_event(_event), do: []

  @spec prompt_text(String.t() | Context.t() | term()) :: {:ok, String.t()} | {:error, term()}
  def prompt_text(prompt) when is_binary(prompt) and prompt != "" do
    {:ok, prompt}
  end

  def prompt_text(prompt) do
    with {:ok, context} <- Context.normalize(prompt),
         {:ok, rendered} <- render_messages(Context.to_list(context)) do
      if rendered == "" do
        {:error,
         Error.Invalid.Parameter.exception(parameter: "Codex CLI expects a non-empty text prompt")}
      else
        {:ok, rendered}
      end
    end
  end

  defp provider_options(opts) do
    opts
    |> Keyword.get(:provider_options, [])
    |> normalize_provider_options()
    |> Keyword.take(@provider_option_keys)
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp executable(provider_options) do
    candidate = provider_options[:codex_executable] || "codex"
    resolved = System.find_executable(candidate) || local_executable(candidate)

    if is_binary(resolved) do
      {:ok, resolved}
    else
      {:error,
       Error.Invalid.Provider.exception(
         provider: :codex_cli,
         message:
           "Codex CLI executable not found. Install `codex` or pass provider_options[:codex_executable]."
       )}
    end
  end

  defp local_executable(candidate) when is_binary(candidate) do
    expanded = Path.expand(candidate)

    if File.regular?(expanded) do
      expanded
    else
      nil
    end
  end

  defp working_directory(provider_options) do
    case provider_options[:codex_working_dir] do
      cwd when is_binary(cwd) ->
        {:ok, cwd, []}

      _other ->
        tmp_dir =
          Path.join(
            System.tmp_dir!(),
            "req_llm_next_codex_cli_#{System.unique_integer([:positive])}"
          )

        File.mkdir_p!(tmp_dir)
        {:ok, tmp_dir, [tmp_dir]}
    end
  end

  defp maybe_schema_path(opts, cleanup_paths) do
    case {Keyword.get(opts, :compiled_schema), Keyword.get(opts, :_structured_output_strategy)} do
      {%{schema: schema}, :native_json_schema} when not is_nil(schema) ->
        path =
          Path.join(
            System.tmp_dir!(),
            "req_llm_next_codex_schema_#{System.unique_integer([:positive])}.json"
          )

        File.write!(path, Jason.encode!(Schema.to_json(schema)))
        {:ok, path, [path | cleanup_paths]}

      _other ->
        {:ok, nil, cleanup_paths}
    end
  end

  defp args(model, prompt_text, provider_options, schema_path) do
    base_args = [
      "exec",
      "--json",
      "--ephemeral",
      "--skip-git-repo-check",
      "--sandbox",
      "read-only",
      "--model",
      model.id
    ]

    profile_args =
      case provider_options[:codex_profile] do
        profile when is_binary(profile) and profile != "" -> ["--profile", profile]
        _other -> []
      end

    schema_args =
      case schema_path do
        path when is_binary(path) -> ["--output-schema", path]
        _other -> []
      end

    base_args ++ profile_args ++ schema_args ++ [prompt_text]
  end

  defp env(provider_mod, opts, provider_options) do
    env =
      provider_options
      |> Keyword.get(:codex_env, [])
      |> normalize_env()

    api_key = provider_mod.get_api_key(opts)

    if api_key == "" do
      env
    else
      [{"OPENAI_API_KEY", api_key} | env]
    end
  end

  defp normalize_env(env) when is_map(env), do: Enum.into(env, [])
  defp normalize_env(env) when is_list(env), do: Enum.filter(env, &valid_env_entry?/1)
  defp normalize_env(_env), do: []

  defp valid_env_entry?({key, value}) when is_binary(key) and is_binary(value), do: true
  defp valid_env_entry?(_entry), do: false

  defp request_body(model, prompt_text, args, env, opts) do
    %{
      "model" => model.id,
      "prompt" => prompt_text,
      "args" => args,
      "env_keys" => Enum.map(env, &elem(&1, 0)),
      "structured_output" =>
        Keyword.get(opts, :_structured_output_strategy) == :native_json_schema
    }
  end

  defp render_messages(messages) do
    Enum.reduce_while(messages, {:ok, []}, fn message, {:ok, acc} ->
      case render_message(message) do
        {:ok, ""} -> {:cont, {:ok, acc}}
        {:ok, rendered} -> {:cont, {:ok, acc ++ [rendered]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, rendered_messages} -> {:ok, Enum.join(rendered_messages, "\n\n")}
      {:error, _} = error -> error
    end
  end

  defp render_message(%Message{role: :tool}) do
    {:error,
     Error.Invalid.Parameter.exception(
       parameter: "Codex CLI does not support prior tool-result messages in this MVP spike"
     )}
  end

  defp render_message(%Message{tool_calls: tool_calls})
       when is_list(tool_calls) and tool_calls != [] do
    {:error,
     Error.Invalid.Parameter.exception(
       parameter: "Codex CLI does not support assistant tool-call history in this MVP spike"
     )}
  end

  defp render_message(%Message{role: role, content: content}) do
    with {:ok, body} <- render_parts(content) do
      if body == "" do
        {:ok, ""}
      else
        {:ok, "#{rendered_role(role)}:\n#{body}"}
      end
    end
  end

  defp render_parts(parts) do
    Enum.reduce_while(parts, {:ok, []}, fn part, {:ok, acc} ->
      case render_part(part) do
        {:ok, ""} -> {:cont, {:ok, acc}}
        {:ok, rendered} -> {:cont, {:ok, acc ++ [rendered]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, rendered_parts} -> {:ok, Enum.join(rendered_parts, "\n")}
      {:error, _} = error -> error
    end
  end

  defp render_part(%ContentPart{type: :text, text: text}) when is_binary(text), do: {:ok, text}

  defp render_part(%ContentPart{type: :thinking, text: text}) when is_binary(text),
    do: {:ok, text}

  defp render_part(%ContentPart{type: type}) do
    {:error,
     Error.Invalid.Parameter.exception(
       parameter:
         "Codex CLI only supports text context today; unsupported content part #{inspect(type)}"
     )}
  end

  defp rendered_role(:assistant), do: "Assistant"
  defp rendered_role(:system), do: "System"
  defp rendered_role(:tool), do: "Tool"
  defp rendered_role(_role), do: "User"
end
