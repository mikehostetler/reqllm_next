defmodule ReqLlmNext.PublicAPI.CodexCLITest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.{Context, Error, Response, TestModels}

  @object_schema [
    name: [type: :string, required: true]
  ]

  describe "codex_cli provider" do
    test "generates text through the public API with a local executable override" do
      executable = fake_codex_executable()

      {:ok, response} =
        ReqLlmNext.generate_text(
          TestModels.codex_cli(),
          "Say hello",
          provider_options: [codex_executable: executable]
        )

      assert %Response{} = response
      assert Response.text(response) == "hello from codex cli"
      assert response.finish_reason == :stop
      assert response.usage.input_tokens == 12
      assert response.usage.output_tokens == 4
      assert response.usage.cache_read_tokens == 3
    end

    test "generates objects through Codex output-schema mode" do
      executable = fake_codex_executable()

      {:ok, response} =
        ReqLlmNext.generate_object(
          TestModels.codex_cli(),
          "Return a name object",
          @object_schema,
          provider_options: [codex_executable: executable]
        )

      assert %Response{} = response
      assert response.object == %{"name" => "Ada"}
      assert response.finish_reason == :stop
    end

    test "rejects assistant tool-call history in the MVP spike" do
      executable = fake_codex_executable()

      context =
        ReqLlmNext.context([
          Context.user("Search for a result"),
          Context.assistant("", tool_calls: [{"lookup", %{query: "result"}}])
        ])

      assert {:error, %Error.Invalid.Parameter{} = error} =
               ReqLlmNext.generate_text(
                 TestModels.codex_cli(),
                 context,
                 provider_options: [codex_executable: executable]
               )

      assert Exception.message(error) =~ "assistant tool-call history"
    end
  end

  defp fake_codex_executable do
    path =
      Path.join(
        System.tmp_dir!(),
        "req_llm_next_fake_codex_#{System.unique_integer([:positive])}.sh"
      )

    File.write!(
      path,
      """
      #!/bin/sh
      schema=""

      while [ "$#" -gt 0 ]; do
        case "$1" in
          exec|--json|--ephemeral|--skip-git-repo-check)
            shift
            ;;
          --sandbox|--model|--profile)
            shift 2
            ;;
          --output-schema)
            schema="$2"
            shift 2
            ;;
          *)
            prompt="$1"
            shift
            ;;
        esac
      done

      printf '%s\\n' '{"type":"thread.started","thread_id":"test-thread"}'
      printf '%s\\n' '{"type":"turn.started"}'

      if [ -n "$schema" ]; then
        printf '%s\\n' '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"{\\"name\\":\\"Ada\\"}"}}'
      else
        printf '%s\\n' '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"hello from codex cli"}}'
      fi

      printf '%s\\n' '{"type":"turn.completed","usage":{"input_tokens":12,"cached_input_tokens":3,"output_tokens":4}}'
      """
    )

    File.chmod!(path, 0o755)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
