defmodule ReqLlmNext.Coverage.Anthropic.ComprehensiveTest do
  @moduledoc """
  Comprehensive Anthropic API coverage tests.

  Run with REQ_LLM_NEXT_FIXTURES_MODE=record to test against live API and record fixtures.
  Otherwise uses fixtures for fast, reliable testing.
  """

  use ReqLlmNext.ProviderTest.Comprehensive, provider: :anthropic
end
