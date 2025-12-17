defmodule ReqLlmNext.Wire.OpenAIChat do
  @moduledoc """
  Wire protocol for OpenAI Chat Completions API.

  Handles encoding requests for /v1/chat/completions endpoint.
  """

  @base_url "https://api.openai.com/v1"

  @spec build_stream_request(LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_stream_request(model, prompt, opts) do
    api_key = get_api_key(opts)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "text/event-stream"}
    ]

    body =
      %{
        model: model.id,
        messages: [%{role: "user", content: prompt}],
        stream: true,
        stream_options: %{include_usage: true}
      }
      |> maybe_add_max_tokens(opts)
      |> maybe_add_temperature(opts)
      |> Jason.encode!()

    url = @base_url <> "/chat/completions"

    {:ok, Finch.build(:post, url, headers, body)}
  end

  defp get_api_key(opts) do
    Keyword.get(opts, :api_key) ||
      System.get_env("OPENAI_API_KEY") ||
      raise "OPENAI_API_KEY not set"
  end

  defp maybe_add_max_tokens(body, opts) do
    case Keyword.get(opts, :max_tokens) do
      nil -> body
      max_tokens -> Map.put(body, :max_tokens, max_tokens)
    end
  end

  defp maybe_add_temperature(body, opts) do
    case Keyword.get(opts, :temperature) do
      nil -> body
      temperature -> Map.put(body, :temperature, temperature)
    end
  end
end
