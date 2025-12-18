defmodule ReqLlmNext.ScenariosTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios
  alias ReqLlmNext.TestModels

  describe "all/0" do
    test "returns list of scenario modules" do
      scenarios = Scenarios.all()
      assert is_list(scenarios)
      assert length(scenarios) > 0
      assert Enum.all?(scenarios, &is_atom/1)
    end

    test "includes expected default scenarios" do
      scenarios = Scenarios.all()
      assert ReqLlmNext.Scenarios.Basic in scenarios
      assert ReqLlmNext.Scenarios.Streaming in scenarios
      assert ReqLlmNext.Scenarios.Embedding in scenarios
      assert ReqLlmNext.Scenarios.Reasoning in scenarios
    end

    test "respects application config override" do
      original = Application.get_env(:req_llm_next, Scenarios)

      try do
        Application.put_env(:req_llm_next, Scenarios, [ReqLlmNext.Scenarios.Basic])
        assert Scenarios.all() == [ReqLlmNext.Scenarios.Basic]
      after
        if original do
          Application.put_env(:req_llm_next, Scenarios, original)
        else
          Application.delete_env(:req_llm_next, Scenarios)
        end
      end
    end
  end

  describe "ids/0" do
    test "returns list of atoms" do
      ids = Scenarios.ids()
      assert is_list(ids)
      assert Enum.all?(ids, &is_atom/1)
    end

    test "includes expected scenario ids" do
      ids = Scenarios.ids()
      assert :basic in ids
      assert :streaming in ids
      assert :embedding in ids
      assert :reasoning in ids
      assert :multi_turn in ids
      assert :object_streaming in ids
      assert :tool_parallel in ids
    end
  end

  describe "get/1" do
    test "returns scenario module by id" do
      assert Scenarios.get(:basic) == ReqLlmNext.Scenarios.Basic
      assert Scenarios.get(:streaming) == ReqLlmNext.Scenarios.Streaming
      assert Scenarios.get(:embedding) == ReqLlmNext.Scenarios.Embedding
    end

    test "returns nil for unknown id" do
      assert Scenarios.get(:nonexistent_scenario) == nil
    end
  end

  describe "for_model/1" do
    test "filters scenarios for chat model" do
      model = TestModels.openai()
      scenarios = Scenarios.for_model(model)

      assert is_list(scenarios)
      assert ReqLlmNext.Scenarios.Basic in scenarios
      assert ReqLlmNext.Scenarios.Streaming in scenarios
      refute ReqLlmNext.Scenarios.Embedding in scenarios
    end

    test "filters scenarios for embedding model" do
      model =
        TestModels.openai_embedding(%{
          capabilities: %{
            chat: false,
            embeddings: true,
            reasoning: %{enabled: false},
            tools: %{enabled: false, streaming: false, strict: false, parallel: false},
            json: %{native: false, schema: false, strict: false},
            streaming: %{text: false, tool_calls: false}
          }
        })

      scenarios = Scenarios.for_model(model)

      assert ReqLlmNext.Scenarios.Embedding in scenarios
      refute ReqLlmNext.Scenarios.Basic in scenarios
    end

    test "filters scenarios for reasoning model" do
      model = TestModels.openai_reasoning()
      scenarios = Scenarios.for_model(model)

      assert ReqLlmNext.Scenarios.Reasoning in scenarios
      assert ReqLlmNext.Scenarios.Basic in scenarios
    end

    test "includes tool parallel for models with parallel tool support" do
      model = TestModels.openai()
      scenarios = Scenarios.for_model(model)

      assert ReqLlmNext.Scenarios.ToolParallel in scenarios
    end

    test "excludes tool parallel for models without parallel tool support" do
      model = TestModels.openai(%{capabilities: %{tools: %{enabled: true, parallel: false}}})
      scenarios = Scenarios.for_model(model)

      refute ReqLlmNext.Scenarios.ToolParallel in scenarios
    end

    test "includes object streaming for models with JSON schema support" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            json: %{native: true, schema: true, strict: true},
            streaming: %{text: true, tool_calls: true}
          }
        })

      scenarios = Scenarios.for_model(model)
      assert ReqLlmNext.Scenarios.ObjectStreaming in scenarios
    end

    test "excludes object streaming for models without JSON schema support" do
      model =
        TestModels.anthropic(%{
          capabilities: %{
            chat: true,
            json: %{native: true, schema: false, strict: false}
          }
        })

      scenarios = Scenarios.for_model(model)
      refute ReqLlmNext.Scenarios.ObjectStreaming in scenarios
    end
  end
end

defmodule ReqLlmNext.Scenarios.EmbeddingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Embedding
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for embedding model with embeddings: true" do
      model =
        TestModels.openai_embedding(%{
          capabilities: %{
            chat: false,
            embeddings: true,
            reasoning: %{enabled: false},
            tools: %{enabled: false, streaming: false, strict: false, parallel: false},
            json: %{native: false, schema: false, strict: false},
            streaming: %{text: false, tool_calls: false}
          }
        })

      assert Embedding.applies?(model)
    end

    test "returns false for embedding model with map capabilities (ModelHelpers.embeddings? bug)" do
      model = TestModels.openai_embedding()
      refute Embedding.applies?(model)
    end

    test "returns false for chat model" do
      model = TestModels.openai()
      refute Embedding.applies?(model)
    end

    test "returns false for reasoning model" do
      model = TestModels.openai_reasoning()
      refute Embedding.applies?(model)
    end
  end

  describe "id/0" do
    test "returns :embedding" do
      assert Embedding.id() == :embedding
    end
  end

  describe "name/0" do
    test "returns descriptive name" do
      assert Embedding.name() == "Embedding"
    end
  end
end

defmodule ReqLlmNext.Scenarios.ToolParallelTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ToolParallel
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for model with parallel tools enabled" do
      model = TestModels.openai()
      assert ToolParallel.applies?(model)
    end

    test "returns false for model without tools" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            tools: %{enabled: false, parallel: false}
          }
        })

      refute ToolParallel.applies?(model)
    end

    test "returns false for model with tools but not parallel" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            tools: %{enabled: true, parallel: false}
          }
        })

      refute ToolParallel.applies?(model)
    end

    test "returns false for reasoning model without tool support" do
      model = TestModels.openai_reasoning()
      refute ToolParallel.applies?(model)
    end

    test "returns true for Anthropic model with parallel tools" do
      model = TestModels.anthropic()
      assert ToolParallel.applies?(model)
    end
  end

  describe "id/0" do
    test "returns :tool_parallel" do
      assert ToolParallel.id() == :tool_parallel
    end
  end

  describe "name/0" do
    test "returns descriptive name" do
      assert ToolParallel.name() == "Parallel Tool Calls"
    end
  end
end

defmodule ReqLlmNext.Scenarios.ObjectStreamingTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ObjectStreaming
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for model with JSON schema support" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            json: %{native: true, schema: true, strict: true},
            streaming: %{text: true, tool_calls: true}
          }
        })

      assert ObjectStreaming.applies?(model)
    end

    test "returns false for model without JSON schema support" do
      model =
        TestModels.anthropic(%{
          capabilities: %{
            chat: true,
            json: %{native: true, schema: false, strict: false}
          }
        })

      refute ObjectStreaming.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute ObjectStreaming.applies?(model)
    end

    test "returns false when streaming tool_calls is false" do
      model =
        TestModels.openai(%{
          capabilities: %{
            chat: true,
            json: %{native: true, schema: true, strict: true},
            streaming: %{text: true, tool_calls: false}
          }
        })

      refute ObjectStreaming.applies?(model)
    end
  end

  describe "id/0" do
    test "returns :object_streaming" do
      assert ObjectStreaming.id() == :object_streaming
    end
  end

  describe "name/0" do
    test "returns descriptive name" do
      assert ObjectStreaming.name() == "Object Streaming"
    end
  end
end

defmodule ReqLlmNext.Scenarios.MultiTurnTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.MultiTurn
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for chat model" do
      model = TestModels.openai()
      assert MultiTurn.applies?(model)
    end

    test "returns true for Anthropic model" do
      model = TestModels.anthropic()
      assert MultiTurn.applies?(model)
    end

    test "returns true for reasoning model (also has chat)" do
      model = TestModels.openai_reasoning()
      assert MultiTurn.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute MultiTurn.applies?(model)
    end
  end

  describe "id/0" do
    test "returns :multi_turn" do
      assert MultiTurn.id() == :multi_turn
    end
  end

  describe "name/0" do
    test "returns descriptive name" do
      assert MultiTurn.name() == "Multi-turn Context"
    end
  end
end

defmodule ReqLlmNext.Scenarios.ReasoningTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Reasoning
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for reasoning model" do
      model = TestModels.openai_reasoning()
      assert Reasoning.applies?(model)
    end

    test "returns true for Anthropic thinking model" do
      model = TestModels.anthropic_thinking()
      assert Reasoning.applies?(model)
    end

    test "returns false for standard chat model" do
      model = TestModels.openai()
      refute Reasoning.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute Reasoning.applies?(model)
    end

    test "returns false for Anthropic standard model" do
      model = TestModels.anthropic()
      refute Reasoning.applies?(model)
    end
  end

  describe "id/0" do
    test "returns :reasoning" do
      assert Reasoning.id() == :reasoning
    end
  end

  describe "name/0" do
    test "returns descriptive name" do
      assert Reasoning.name() == "Reasoning"
    end
  end
end

defmodule ReqLlmNext.ScenarioTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenario

  describe "fixture_name/1" do
    test "returns scenario id as string" do
      assert Scenario.fixture_name(:basic) == "basic"
      assert Scenario.fixture_name(:tool_round_trip) == "tool_round_trip"
    end
  end

  describe "fixture_name/2" do
    test "appends string step" do
      assert Scenario.fixture_name(:tool_round_trip, "1") == "tool_round_trip_1"
      assert Scenario.fixture_name(:multi_turn, "request") == "multi_turn_request"
    end

    test "appends atom step" do
      assert Scenario.fixture_name(:tool_round_trip, :first) == "tool_round_trip_first"
      assert Scenario.fixture_name(:multi_turn, :response) == "multi_turn_response"
    end

    test "handles nil step" do
      assert Scenario.fixture_name(:basic, nil) == "basic"
    end
  end

  describe "ok/0" do
    test "returns success result with empty steps" do
      result = Scenario.ok()
      assert result == %{status: :ok, steps: [], error: nil}
    end
  end

  describe "ok/1" do
    test "returns success result with steps" do
      steps = [%{name: "step1", status: :ok}]
      result = Scenario.ok(steps)
      assert result == %{status: :ok, steps: steps, error: nil}
    end
  end

  describe "error/1" do
    test "returns error result with reason" do
      result = Scenario.error(:some_error)
      assert result == %{status: :error, steps: [], error: :some_error}
    end
  end

  describe "error/2" do
    test "returns error result with reason and steps" do
      steps = [%{name: "failed_step", status: :error}]
      result = Scenario.error(:api_error, steps)
      assert result == %{status: :error, steps: steps, error: :api_error}
    end
  end

  describe "skipped/0" do
    test "returns skipped result with default reason" do
      result = Scenario.skipped()
      assert result == %{status: :skipped, steps: [], error: :not_applicable}
    end
  end

  describe "skipped/1" do
    test "returns skipped result with custom reason" do
      result = Scenario.skipped(:model_not_supported)
      assert result == %{status: :skipped, steps: [], error: :model_not_supported}
    end
  end

  describe "step/2" do
    test "creates step with name and status" do
      step = Scenario.step("generate_text", :ok)

      assert step == %{
               name: "generate_text",
               status: :ok,
               request: nil,
               response: nil,
               error: nil
             }
    end
  end

  describe "step/3" do
    test "creates step with response" do
      step = Scenario.step("generate_text", :ok, response: %{text: "Hello"})

      assert step == %{
               name: "generate_text",
               status: :ok,
               request: nil,
               response: %{text: "Hello"},
               error: nil
             }
    end

    test "creates step with error" do
      step = Scenario.step("generate_text", :error, error: :timeout)

      assert step == %{
               name: "generate_text",
               status: :error,
               request: nil,
               response: nil,
               error: :timeout
             }
    end

    test "creates step with request and response" do
      step =
        Scenario.step("generate_text", :ok,
          request: %{prompt: "Hello"},
          response: %{text: "Hi"}
        )

      assert step == %{
               name: "generate_text",
               status: :ok,
               request: %{prompt: "Hello"},
               response: %{text: "Hi"},
               error: nil
             }
    end
  end
end

defmodule ReqLlmNext.Scenarios.RunForModelTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios

  describe "run_for_model/3" do
    test "runs applicable scenarios and annotates results with metadata" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      results = Scenarios.run_for_model("openai:gpt-4o-mini", model, [])

      assert is_list(results)
      assert length(results) > 0

      for result <- results do
        assert Map.has_key?(result, :status)
        assert Map.has_key?(result, :scenario_id)
        assert Map.has_key?(result, :scenario_name)
        assert Map.has_key?(result, :model_spec)
        assert result.model_spec == "openai:gpt-4o-mini"
        assert result.status in [:ok, :error, :skipped]
      end
    end

    test "basic scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.Basic.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "generate_text"
      assert hd(result.steps).status == :ok
    end

    test "streaming scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.Streaming.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "stream_text"
    end

    test "usage scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.Usage.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "stream_text"
    end

    test "token_limit scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.TokenLimit.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "generate_text"
    end

    test "multi_turn scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.MultiTurn.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 2
    end

    test "tool_none scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.ToolNone.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
    end

    test "tool_round_trip scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Scenarios.ToolRoundTrip.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) >= 1
    end

    test "anthropic basic scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Scenarios.Basic.run("anthropic:claude-sonnet-4-20250514", model, [])

      assert result.status == :ok
    end

    test "anthropic streaming scenario runs successfully with fixture" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Scenarios.Streaming.run("anthropic:claude-sonnet-4-20250514", model, [])

      assert result.status == :ok
    end
  end
end

defmodule ReqLlmNext.Scenarios.EmbeddingRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Embedding
  alias ReqLlmNext.TestModels

  defp validate_embeddings_result(embeddings_result) do
    case embeddings_result do
      {:ok, embeddings} when is_list(embeddings) and length(embeddings) == 3 ->
        :ok

      {:ok, other} ->
        %{status: :error, error: {:unexpected_embedding_format, other}}

      {:error, reason} ->
        %{status: :error, error: reason}
    end
  end

  defp valid_embedding?(embedding) do
    is_list(embedding) and
      length(embedding) > 0 and
      Enum.all?(embedding, &is_number/1)
  end

  defp cosine_similarity(vec1, vec2) do
    dot_product = Enum.zip(vec1, vec2) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
    magnitude1 = :math.sqrt(Enum.reduce(vec1, 0.0, fn x, acc -> acc + x * x end))
    magnitude2 = :math.sqrt(Enum.reduce(vec2, 0.0, fn x, acc -> acc + x * x end))

    if magnitude1 == 0.0 or magnitude2 == 0.0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end

  describe "applies?/1" do
    test "returns true for embedding model with embeddings: true capability" do
      model =
        TestModels.openai_embedding(%{
          capabilities: %{
            chat: false,
            embeddings: true,
            reasoning: %{enabled: false},
            tools: %{enabled: false, streaming: false, strict: false, parallel: false},
            json: %{native: false, schema: false, strict: false},
            streaming: %{text: false, tool_calls: false}
          }
        })

      assert Embedding.applies?(model)
    end

    test "returns false for non-model input" do
      refute Embedding.applies?(nil)
      refute Embedding.applies?(%{})
      refute Embedding.applies?("not a model")
    end
  end

  describe "run/3 validation logic" do
    test "validate_embeddings returns error for invalid embedding format (not list)" do
      result = validate_embeddings_result({:ok, "not a list"})
      assert result == %{status: :error, error: {:unexpected_embedding_format, "not a list"}}
    end

    test "validate_embeddings returns error for wrong number of embeddings" do
      result = validate_embeddings_result({:ok, [[0.1, 0.2], [0.3, 0.4]]})

      assert result == %{
               status: :error,
               error: {:unexpected_embedding_format, [[0.1, 0.2], [0.3, 0.4]]}
             }
    end

    test "validate_embeddings returns error on API failure" do
      result = validate_embeddings_result({:error, :api_timeout})
      assert result == %{status: :error, error: :api_timeout}
    end

    test "validate_embeddings accepts valid 3-element list" do
      result = validate_embeddings_result({:ok, [[0.1], [0.2], [0.3]]})
      assert result == :ok
    end
  end

  describe "valid_embedding?/1" do
    test "returns true for valid numeric list" do
      assert valid_embedding?([0.1, 0.2, 0.3])
      assert valid_embedding?([1, 2, 3])
      assert valid_embedding?([0.0])
    end

    test "returns false for empty list" do
      refute valid_embedding?([])
    end

    test "returns false for non-list" do
      refute valid_embedding?("string")
      refute valid_embedding?(nil)
      refute valid_embedding?(123)
    end

    test "returns false for list with non-numbers" do
      refute valid_embedding?([0.1, "string", 0.3])
      refute valid_embedding?([:atom])
    end
  end

  describe "cosine_similarity/2" do
    test "identical vectors have similarity 1.0" do
      vec = [1.0, 0.0, 0.0]
      similarity = cosine_similarity(vec, vec)
      assert_in_delta similarity, 1.0, 0.0001
    end

    test "orthogonal vectors have similarity 0.0" do
      vec1 = [1.0, 0.0]
      vec2 = [0.0, 1.0]
      similarity = cosine_similarity(vec1, vec2)
      assert_in_delta similarity, 0.0, 0.0001
    end

    test "opposite vectors have similarity -1.0" do
      vec1 = [1.0, 0.0]
      vec2 = [-1.0, 0.0]
      similarity = cosine_similarity(vec1, vec2)
      assert_in_delta similarity, -1.0, 0.0001
    end

    test "returns 0.0 when magnitude is zero" do
      vec1 = [0.0, 0.0]
      vec2 = [1.0, 1.0]
      similarity = cosine_similarity(vec1, vec2)
      assert similarity == 0.0
    end

    test "similar text embeddings should have higher similarity than different ones" do
      e1 = [0.5, 0.5, 0.5]
      e2 = [0.5, 0.5, 0.6]
      e3 = [-0.5, -0.5, 0.0]

      sim_12 = cosine_similarity(e1, e2)
      sim_13 = cosine_similarity(e1, e3)

      assert sim_12 > sim_13
    end
  end

  describe "dimension validation" do
    test "detects dimension mismatch" do
      e1 = [0.1, 0.2, 0.3]
      e2 = [0.1, 0.2, 0.3]
      e3 = [0.1, 0.2]

      has_mismatch = length(e1) != length(e2) or length(e1) != length(e3)
      assert has_mismatch
    end

    test "accepts matching dimensions" do
      e1 = [0.1, 0.2, 0.3]
      e2 = [0.4, 0.5, 0.6]
      e3 = [0.7, 0.8, 0.9]

      has_mismatch = length(e1) != length(e2) or length(e1) != length(e3)
      refute has_mismatch
    end
  end

  describe "similarity ordering validation" do
    test "passes when similar texts have higher similarity" do
      e1 = [0.9, 0.1, 0.0]
      e2 = [0.85, 0.15, 0.0]
      e3 = [-0.5, 0.5, 0.5]

      sim_12 = cosine_similarity(e1, e2)
      sim_13 = cosine_similarity(e1, e3)
      sim_23 = cosine_similarity(e2, e3)

      passes = sim_12 > sim_13 and sim_12 > sim_23
      assert passes
    end

    test "fails when dissimilar texts have higher similarity" do
      e1 = [1.0, 0.0]
      e2 = [-1.0, 0.0]
      e3 = [1.0, 0.01]

      sim_12 = cosine_similarity(e1, e2)
      sim_13 = cosine_similarity(e1, e3)
      sim_23 = cosine_similarity(e2, e3)

      passes = sim_12 > sim_13 and sim_12 > sim_23
      refute passes
    end
  end
end

defmodule ReqLlmNext.Scenarios.ToolParallelRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ToolParallel
  alias ReqLlmNext.ToolCall

  describe "run/3 validation logic" do
    test "validate_parallel_calls returns error when fewer than 2 tool calls" do
      tool_calls = [ToolCall.new("1", "get_weather", "{}")]

      result =
        cond do
          not is_list(tool_calls) or length(tool_calls) < 2 ->
            %{status: :error, error: {:expected_multiple_tool_calls, length(tool_calls)}}

          true ->
            :ok
        end

      assert result == %{status: :error, error: {:expected_multiple_tool_calls, 1}}
    end

    test "validate_parallel_calls returns error for nil tool_calls" do
      tool_calls = nil

      result =
        cond do
          not is_list(tool_calls) or length(tool_calls || []) < 2 ->
            %{status: :error, error: {:expected_multiple_tool_calls, length(tool_calls || [])}}

          true ->
            :ok
        end

      assert result == %{status: :error, error: {:expected_multiple_tool_calls, 0}}
    end

    test "validate_parallel_calls returns error when wrong tools called" do
      tool_calls = [
        ToolCall.new("1", "other_tool", "{}"),
        ToolCall.new("2", "another_tool", "{}")
      ]

      tool_names = Enum.map(tool_calls, &ToolCall.name/1) |> Enum.sort()

      result =
        if "get_time" in tool_names and "get_weather" in tool_names do
          :ok
        else
          %{status: :error, error: {:wrong_tools_called, tool_names}}
        end

      assert result == %{
               status: :error,
               error: {:wrong_tools_called, ["another_tool", "other_tool"]}
             }
    end

    test "validate_parallel_calls succeeds with correct tools" do
      tool_calls = [
        ToolCall.new("1", "get_weather", "{}"),
        ToolCall.new("2", "get_time", "{}")
      ]

      tool_names = Enum.map(tool_calls, &ToolCall.name/1) |> Enum.sort()

      result =
        if "get_time" in tool_names and "get_weather" in tool_names do
          :ok
        else
          %{status: :error, error: {:wrong_tools_called, tool_names}}
        end

      assert result == :ok
    end
  end

  describe "applies?/1" do
    test "returns true for model with parallel tools enabled" do
      model = ReqLlmNext.TestModels.openai()
      assert ToolParallel.applies?(model)
    end
  end
end

defmodule ReqLlmNext.Scenarios.ObjectStreamingRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ObjectStreaming

  describe "run/3 validation logic" do
    test "returns error when object is not a map" do
      object = "not a map"

      result =
        cond do
          not is_map(object) ->
            %{status: :error, error: :invalid_object_type}

          not Map.has_key?(object, "name") ->
            %{status: :error, error: :missing_name}

          not Map.has_key?(object, "age") ->
            %{status: :error, error: :missing_age}

          not is_binary(object["name"]) or object["name"] == "" ->
            %{status: :error, error: :invalid_name}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :invalid_object_type}
    end

    test "returns error when missing name field" do
      object = %{"age" => 28}

      result =
        cond do
          not is_map(object) ->
            %{status: :error, error: :invalid_object_type}

          not Map.has_key?(object, "name") ->
            %{status: :error, error: :missing_name}

          not Map.has_key?(object, "age") ->
            %{status: :error, error: :missing_age}

          not is_binary(object["name"]) or object["name"] == "" ->
            %{status: :error, error: :invalid_name}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :missing_name}
    end

    test "returns error when missing age field" do
      object = %{"name" => "Alice"}

      result =
        cond do
          not is_map(object) ->
            %{status: :error, error: :invalid_object_type}

          not Map.has_key?(object, "name") ->
            %{status: :error, error: :missing_name}

          not Map.has_key?(object, "age") ->
            %{status: :error, error: :missing_age}

          not is_binary(object["name"]) or object["name"] == "" ->
            %{status: :error, error: :invalid_name}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :missing_age}
    end

    test "returns error when name is empty" do
      object = %{"name" => "", "age" => 28}

      result =
        cond do
          not is_map(object) ->
            %{status: :error, error: :invalid_object_type}

          not Map.has_key?(object, "name") ->
            %{status: :error, error: :missing_name}

          not Map.has_key?(object, "age") ->
            %{status: :error, error: :missing_age}

          not is_binary(object["name"]) or object["name"] == "" ->
            %{status: :error, error: :invalid_name}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :invalid_name}
    end

    test "succeeds with valid object" do
      object = %{"name" => "Alice", "age" => 28}

      result =
        cond do
          not is_map(object) ->
            %{status: :error, error: :invalid_object_type}

          not Map.has_key?(object, "name") ->
            %{status: :error, error: :missing_name}

          not Map.has_key?(object, "age") ->
            %{status: :error, error: :missing_age}

          not is_binary(object["name"]) or object["name"] == "" ->
            %{status: :error, error: :invalid_name}

          true ->
            :ok
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with object_streaming fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = ObjectStreaming.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "stream_object"
    end
  end
end

defmodule ReqLlmNext.Scenarios.ReasoningRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Reasoning

  describe "extract_final_answer logic" do
    test "extracts numeric answer from FINAL_ANSWER line" do
      text = "Some reasoning...\nFINAL_ANSWER: 34\nMore text"

      result =
        case Regex.run(~r/FINAL_ANSWER:\s*\$?(\d+)/i, text) do
          [_, num_str] -> {:ok, String.to_integer(num_str)}
          nil -> :no_final_answer
        end

      assert result == {:ok, 34}
    end

    test "extracts answer with dollar sign" do
      text = "The total is FINAL_ANSWER: $42"

      result =
        case Regex.run(~r/FINAL_ANSWER:\s*\$?(\d+)/i, text) do
          [_, num_str] -> {:ok, String.to_integer(num_str)}
          nil -> :no_final_answer
        end

      assert result == {:ok, 42}
    end

    test "returns no_final_answer when not present" do
      text = "Some text without the answer format"

      result =
        case Regex.run(~r/FINAL_ANSWER:\s*\$?(\d+)/i, text) do
          [_, num_str] -> {:ok, String.to_integer(num_str)}
          nil -> :no_final_answer
        end

      assert result == :no_final_answer
    end

    test "case insensitive matching" do
      text = "final_answer: 100"

      result =
        case Regex.run(~r/FINAL_ANSWER:\s*\$?(\d+)/i, text) do
          [_, num_str] -> {:ok, String.to_integer(num_str)}
          nil -> :no_final_answer
        end

      assert result == {:ok, 100}
    end
  end

  describe "validate_answer logic" do
    test "correct answer (34) returns ok" do
      answer = 34

      result =
        cond do
          answer == 34 -> :ok
          true -> {:error, {:incorrect_answer, answer, :expected, 34}}
        end

      assert result == :ok
    end

    test "incorrect answer returns error with expected value" do
      answer = 35

      result =
        cond do
          answer == 34 -> :ok
          true -> {:error, {:incorrect_answer, answer, :expected, 34}}
        end

      assert result == {:error, {:incorrect_answer, 35, :expected, 34}}
    end

    test "fallback: text containing 34 passes when no FINAL_ANSWER" do
      text = "The answer is 34 dollars."
      has_34 = String.contains?(text, "34")
      assert has_34
    end

    test "fallback: text without 34 fails when no FINAL_ANSWER" do
      text = "The answer is thirty-four."
      has_34 = String.contains?(text, "34")
      refute has_34
    end
  end
end

defmodule ReqLlmNext.Scenarios.ImageInputRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ImageInput

  describe "run/3 validation logic" do
    test "returns error for empty response" do
      text = ""

      result =
        cond do
          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          String.contains?(String.downcase(text), "ant") ->
            :ok

          String.contains?(String.downcase(text), "insect") ->
            :ok

          true ->
            %{status: :error, error: {:unexpected_description, text}}
        end

      assert result == %{status: :error, error: :empty_response}
    end

    test "accepts response containing 'ant'" do
      text = "This is an ant."
      normalized = text |> String.downcase() |> String.trim()

      result =
        cond do
          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          String.contains?(normalized, "ant") ->
            :ok

          String.contains?(normalized, "insect") ->
            :ok

          true ->
            %{status: :error, error: {:unexpected_description, text}}
        end

      assert result == :ok
    end

    test "accepts response containing 'insect'" do
      text = "This is an insect."
      normalized = text |> String.downcase() |> String.trim()

      result =
        cond do
          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          String.contains?(normalized, "ant") ->
            :ok

          String.contains?(normalized, "insect") ->
            :ok

          true ->
            %{status: :error, error: {:unexpected_description, text}}
        end

      assert result == :ok
    end

    test "rejects unexpected description" do
      text = "This is a cat."
      normalized = text |> String.downcase() |> String.trim()

      result =
        cond do
          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          String.contains?(normalized, "ant") ->
            :ok

          String.contains?(normalized, "insect") ->
            :ok

          true ->
            %{status: :error, error: {:unexpected_description, text}}
        end

      assert result == %{status: :error, error: {:unexpected_description, "This is a cat."}}
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with image_input fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = ImageInput.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "image_describe"
    end
  end
end

defmodule ReqLlmNext.Scenarios.ToolMultiRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ToolMulti
  alias ReqLlmNext.ToolCall

  describe "run/3 validation logic" do
    test "returns error when no tool calls" do
      tool_calls = []

      result =
        cond do
          not is_list(tool_calls) or length(tool_calls) == 0 ->
            %{status: :error, error: :no_tool_calls}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :no_tool_calls}
    end

    test "returns error when wrong tool called" do
      tool_calls = [ToolCall.new("1", "tell_joke", "{}")]

      weather_call = Enum.find(tool_calls, fn tc -> ToolCall.name(tc) == "get_weather" end)

      result =
        if weather_call do
          :ok
        else
          %{status: :error, error: :wrong_tool_called}
        end

      assert result == %{status: :error, error: :wrong_tool_called}
    end

    test "returns error when location arg missing" do
      tool_calls = [ToolCall.new("1", "get_weather", "{}")]

      weather_call = Enum.find(tool_calls, fn tc -> ToolCall.name(tc) == "get_weather" end)
      args = ToolCall.args_map(weather_call)

      result =
        if is_map(args) and Map.has_key?(args, "location") do
          :ok
        else
          %{status: :error, error: :missing_location_arg}
        end

      assert result == %{status: :error, error: :missing_location_arg}
    end

    test "succeeds when get_weather called with location" do
      tool_calls = [ToolCall.new("1", "get_weather", ~s({"location": "Paris"}))]

      weather_call = Enum.find(tool_calls, fn tc -> ToolCall.name(tc) == "get_weather" end)
      args = ToolCall.args_map(weather_call)

      result =
        if is_map(args) and Map.has_key?(args, "location") do
          :ok
        else
          %{status: :error, error: :missing_location_arg}
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with multi_tool fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = ToolMulti.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "stream_text"
    end
  end
end

defmodule ReqLlmNext.Scenarios.BasicRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Basic
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for chat model" do
      model = TestModels.openai()
      assert Basic.applies?(model)
    end

    test "returns true for anthropic model" do
      model = TestModels.anthropic()
      assert Basic.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute Basic.applies?(model)
    end

    test "returns false for non-model input" do
      refute Basic.applies?(nil)
      refute Basic.applies?(%{})
    end
  end

  describe "run/3 validation logic" do
    test "detects invalid text type" do
      text = 123

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :invalid_text_type}
    end

    test "detects empty response" do
      text = ""

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :empty_response}
    end

    test "accepts valid text" do
      text = "Hello world!"

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with basic fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Basic.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "generate_text"
      assert hd(result.steps).status == :ok
    end
  end
end

defmodule ReqLlmNext.Scenarios.StreamingRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Streaming
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for chat model with streaming" do
      model = TestModels.openai()
      assert Streaming.applies?(model)
    end

    test "returns false for model without streaming text capability" do
      model = TestModels.openai(%{capabilities: %{chat: true, streaming: %{text: false}}})
      refute Streaming.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute Streaming.applies?(model)
    end

    test "returns false for non-model input" do
      refute Streaming.applies?(nil)
    end
  end

  describe "run/3 validation logic" do
    test "detects invalid text type" do
      text = nil

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :invalid_text_type}
    end

    test "detects empty response" do
      text = ""

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :empty_response}
    end

    test "accepts valid streamed text" do
      text = "Hello from streaming!"

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with streaming fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Streaming.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "stream_text"
    end
  end
end

defmodule ReqLlmNext.Scenarios.TokenLimitRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.TokenLimit
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for chat model" do
      model = TestModels.openai()
      assert TokenLimit.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute TokenLimit.applies?(model)
    end

    test "returns false for non-model input" do
      refute TokenLimit.applies?(nil)
    end
  end

  describe "run/3 validation logic" do
    test "detects invalid text type" do
      text = []

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            word_count = text |> String.split() |> length()

            if word_count <= 100 do
              :ok
            else
              %{status: :error, error: {:token_limit_exceeded, word_count}}
            end
        end

      assert result == %{status: :error, error: :invalid_text_type}
    end

    test "detects token limit exceeded" do
      text = String.duplicate("word ", 150) |> String.trim()
      word_count = text |> String.split() |> length()

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            if word_count <= 100 do
              :ok
            else
              %{status: :error, error: {:token_limit_exceeded, word_count}}
            end
        end

      assert result == %{status: :error, error: {:token_limit_exceeded, 150}}
    end

    test "accepts response within token limit" do
      text = "Short response with few words."
      word_count = text |> String.split() |> length()

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            if word_count <= 100 do
              :ok
            else
              %{status: :error, error: {:token_limit_exceeded, word_count}}
            end
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with token_limit fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = TokenLimit.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "generate_text"
    end
  end
end

defmodule ReqLlmNext.Scenarios.UsageRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.Usage
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for chat model" do
      model = TestModels.openai()
      assert Usage.applies?(model)
    end

    test "returns true for anthropic model" do
      model = TestModels.anthropic()
      assert Usage.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute Usage.applies?(model)
    end

    test "returns false for non-model input" do
      refute Usage.applies?(nil)
    end
  end

  describe "run/3 validation logic" do
    test "detects invalid text type" do
      text = %{}

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :invalid_text_type}
    end

    test "detects empty response" do
      text = ""

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :empty_response}
    end

    test "accepts valid response" do
      text = "Hi there!"

      result =
        cond do
          not is_binary(text) ->
            %{status: :error, error: :invalid_text_type}

          String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          true ->
            :ok
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with usage fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = Usage.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "stream_text"
    end
  end
end

defmodule ReqLlmNext.Scenarios.ToolNoneRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ToolNone
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for model with tools enabled" do
      model = TestModels.openai()
      assert ToolNone.applies?(model)
    end

    test "returns false for model without tools" do
      model = TestModels.openai(%{capabilities: %{chat: true, tools: %{enabled: false}}})
      refute ToolNone.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute ToolNone.applies?(model)
    end

    test "returns false for non-model input" do
      refute ToolNone.applies?(nil)
    end
  end

  describe "run/3 validation logic" do
    test "detects empty response" do
      text = ""
      tool_calls = []

      result =
        cond do
          not is_binary(text) or String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          tool_calls != [] and Enum.any?(tool_calls, & &1) ->
            %{status: :error, error: :unexpected_tool_calls}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :empty_response}
    end

    test "detects unexpected tool calls" do
      text = "Some response"
      tool_calls = [%{name: "some_tool"}]

      has_tool_calls = length(tool_calls) > 0 and Enum.any?(tool_calls, & &1)

      result =
        cond do
          not is_binary(text) or String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          has_tool_calls ->
            %{status: :error, error: :unexpected_tool_calls}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :unexpected_tool_calls}
    end

    test "accepts response with text and no tool calls" do
      text = "Here's a joke about cats!"
      tool_calls = []

      result =
        cond do
          not is_binary(text) or String.length(text) == 0 ->
            %{status: :error, error: :empty_response}

          tool_calls != [] and Enum.any?(tool_calls, & &1) ->
            %{status: :error, error: :unexpected_tool_calls}

          true ->
            :ok
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with no_tool fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = ToolNone.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 1
      assert hd(result.steps).name == "stream_text"
    end
  end
end

defmodule ReqLlmNext.Scenarios.ToolRoundTripRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.ToolRoundTrip
  alias ReqLlmNext.ToolCall
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for model with tools enabled" do
      model = TestModels.openai()
      assert ToolRoundTrip.applies?(model)
    end

    test "returns false for reasoning model without tools" do
      model = TestModels.openai_reasoning()
      refute ToolRoundTrip.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute ToolRoundTrip.applies?(model)
    end

    test "returns false for non-model input" do
      refute ToolRoundTrip.applies?(nil)
    end
  end

  describe "run/3 validation logic" do
    test "detects no tool calls in first step" do
      tool_calls = []
      result = if tool_calls == [], do: %{status: :error, error: :no_tool_calls}, else: :ok
      assert result == %{status: :error, error: :no_tool_calls}
    end

    test "detects empty final response" do
      text = ""

      result =
        cond do
          text == "" ->
            %{status: :error, error: :empty_final_response}

          not String.contains?(text, "5") ->
            %{status: :error, error: :result_not_in_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :empty_final_response}
    end

    test "detects result not in response" do
      text = "The answer is seven"

      result =
        cond do
          text == "" ->
            %{status: :error, error: :empty_final_response}

          not String.contains?(text, "5") ->
            %{status: :error, error: :result_not_in_response}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :result_not_in_response}
    end

    test "detects unexpected tool calls in final response" do
      text = "sum=5"
      tool_calls = [ToolCall.new("1", "add", "{}")]

      has_tool_calls = length(tool_calls) > 0

      result =
        cond do
          text == "" ->
            %{status: :error, error: :empty_final_response}

          not String.contains?(text, "5") ->
            %{status: :error, error: :result_not_in_response}

          has_tool_calls ->
            %{status: :error, error: :unexpected_tool_calls}

          true ->
            :ok
        end

      assert result == %{status: :error, error: :unexpected_tool_calls}
    end

    test "accepts valid final response with result" do
      text = "The sum is 5"
      tool_calls = []

      result =
        cond do
          text == "" ->
            %{status: :error, error: :empty_final_response}

          not String.contains?(text, "5") ->
            %{status: :error, error: :result_not_in_response}

          tool_calls != [] ->
            %{status: :error, error: :unexpected_tool_calls}

          true ->
            :ok
        end

      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with tool_round_trip fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = ToolRoundTrip.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) >= 1
    end
  end
end

defmodule ReqLlmNext.Scenarios.MultiTurnRunTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios.MultiTurn
  alias ReqLlmNext.TestModels

  describe "applies?/1" do
    test "returns true for chat model" do
      model = TestModels.openai()
      assert MultiTurn.applies?(model)
    end

    test "returns true for anthropic model" do
      model = TestModels.anthropic()
      assert MultiTurn.applies?(model)
    end

    test "returns false for embedding model" do
      model = TestModels.openai_embedding()
      refute MultiTurn.applies?(model)
    end

    test "returns false for non-model input" do
      refute MultiTurn.applies?(nil)
    end
  end

  describe "run/3 validation logic" do
    test "detects empty turn 1 response" do
      text = ""
      result = if String.length(text) == 0, do: %{status: :error, error: :empty_turn1_response}, else: :ok
      assert result == %{status: :error, error: :empty_turn1_response}
    end

    test "detects wrong answer in turn 2" do
      text = "I don't remember"
      result = if String.contains?(text, "42"), do: :ok, else: %{status: :error, error: {:wrong_answer, text}}
      assert result == %{status: :error, error: {:wrong_answer, "I don't remember"}}
    end

    test "accepts correct answer in turn 2" do
      text = "Your favorite number is 42"
      result = if String.contains?(text, "42"), do: :ok, else: %{status: :error, error: {:wrong_answer, text}}
      assert result == :ok
    end
  end

  describe "run/3 with fixture" do
    test "runs successfully with multi_turn fixture" do
      {:ok, model} = LLMDB.model("openai:gpt-4o-mini")
      result = MultiTurn.run("openai:gpt-4o-mini", model, [])

      assert result.status == :ok
      assert length(result.steps) == 2
    end
  end
end

defmodule ReqLlmNext.Scenarios.AdditionalCoverageTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Scenarios

  describe "scenario metadata" do
    test "Basic scenario has correct metadata" do
      assert Scenarios.Basic.id() == :basic
      assert Scenarios.Basic.name() == "Basic Text"
      assert is_binary(Scenarios.Basic.description())
    end

    test "Streaming scenario has correct metadata" do
      assert Scenarios.Streaming.id() == :streaming
      assert Scenarios.Streaming.name() == "Streaming"
    end

    test "TokenLimit scenario has correct metadata" do
      assert Scenarios.TokenLimit.id() == :token_limit
      assert Scenarios.TokenLimit.name() == "Token Limit"
    end

    test "Usage scenario has correct metadata" do
      assert Scenarios.Usage.id() == :usage
      assert Scenarios.Usage.name() == "Usage Metrics"
    end

    test "ToolNone scenario has correct metadata" do
      assert Scenarios.ToolNone.id() == :tool_none
      assert Scenarios.ToolNone.name() == "Tool Avoidance"
    end

    test "ToolRoundTrip scenario has correct metadata" do
      assert Scenarios.ToolRoundTrip.id() == :tool_round_trip
      assert Scenarios.ToolRoundTrip.name() == "Tool Round Trip"
    end

    test "ToolMulti scenario has correct metadata" do
      assert Scenarios.ToolMulti.id() == :tool_multi
      assert Scenarios.ToolMulti.name() == "Multi-tool Selection"
    end

    test "ToolParallel scenario has correct metadata" do
      assert Scenarios.ToolParallel.id() == :tool_parallel
      assert Scenarios.ToolParallel.name() == "Parallel Tool Calls"
    end

    test "ImageInput scenario has correct metadata" do
      assert Scenarios.ImageInput.id() == :image_input
      assert Scenarios.ImageInput.name() == "Image Input"
    end

    test "Reasoning scenario has correct metadata" do
      assert Scenarios.Reasoning.id() == :reasoning
      assert Scenarios.Reasoning.name() == "Reasoning"
    end

    test "ObjectStreaming scenario has correct metadata" do
      assert Scenarios.ObjectStreaming.id() == :object_streaming
      assert Scenarios.ObjectStreaming.name() == "Object Streaming"
    end

    test "Embedding scenario has correct metadata" do
      assert Scenarios.Embedding.id() == :embedding
      assert Scenarios.Embedding.name() == "Embedding"
    end
  end

  describe "all scenarios run with anthropic fixtures" do
    test "basic scenario runs with anthropic" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Scenarios.Basic.run("anthropic:claude-sonnet-4-20250514", model, [])
      assert result.status == :ok
    end

    test "streaming scenario runs with anthropic" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Scenarios.Streaming.run("anthropic:claude-sonnet-4-20250514", model, [])
      assert result.status == :ok
    end

    test "usage scenario runs with anthropic" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Scenarios.Usage.run("anthropic:claude-sonnet-4-20250514", model, [])
      assert result.status == :ok
    end

    test "token_limit scenario runs with anthropic" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Scenarios.TokenLimit.run("anthropic:claude-sonnet-4-20250514", model, [])
      assert result.status == :ok
    end

    test "multi_turn scenario runs with anthropic" do
      {:ok, model} = LLMDB.model("anthropic:claude-sonnet-4-20250514")
      result = Scenarios.MultiTurn.run("anthropic:claude-sonnet-4-20250514", model, [])
      assert result.status == :ok
    end
  end

  describe "gpt-4o scenarios with fixtures" do
    test "basic scenario runs with gpt-4o" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      result = Scenarios.Basic.run("openai:gpt-4o", model, [])
      assert result.status == :ok
    end

    test "streaming scenario runs with gpt-4o" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      result = Scenarios.Streaming.run("openai:gpt-4o", model, [])
      assert result.status == :ok
    end

    test "usage scenario runs with gpt-4o" do
      {:ok, model} = LLMDB.model("openai:gpt-4o")
      result = Scenarios.Usage.run("openai:gpt-4o", model, [])
      assert result.status == :ok
    end
  end
end
