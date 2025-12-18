defmodule ReqLlmNext.ErrorTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Error
  alias ReqLlmNext.Error.API
  alias ReqLlmNext.Error.Invalid
  alias ReqLlmNext.Error.Unknown
  alias ReqLlmNext.Error.Validation

  describe "Invalid.Parameter" do
    test "creates error with parameter field" do
      error = Invalid.Parameter.exception(parameter: "model: invalid format")
      assert error.parameter == "model: invalid format"
      assert Exception.message(error) =~ "Invalid parameter"
    end

    test "belongs to invalid class" do
      error = Invalid.Parameter.exception(parameter: "test")
      assert error.class == :invalid
    end
  end

  describe "Invalid.Provider" do
    test "creates error with provider field" do
      error = Invalid.Provider.exception(provider: :unknown_provider)
      assert error.provider == :unknown_provider
      assert Exception.message(error) =~ "Unknown provider"
    end

    test "uses message field when provided" do
      error = Invalid.Provider.exception(provider: :test, message: "Custom message")
      assert Exception.message(error) == "Custom message"
    end

    test "belongs to invalid class" do
      error = Invalid.Provider.exception(provider: :test)
      assert error.class == :invalid
    end
  end

  describe "Invalid.Capability" do
    test "creates error with missing capabilities" do
      error = Invalid.Capability.exception(missing: [:streaming, :tools])
      assert error.missing == [:streaming, :tools]
      assert Exception.message(error) =~ "Unsupported capabilities"
    end

    test "uses message field when provided" do
      error = Invalid.Capability.exception(message: "Model does not support tools")
      assert Exception.message(error) == "Model does not support tools"
    end

    test "belongs to invalid class" do
      error = Invalid.Capability.exception(missing: [:test])
      assert error.class == :invalid
    end
  end

  describe "API.Request" do
    test "creates error with status and reason" do
      error =
        API.Request.exception(
          reason: "Rate limited",
          status: 429,
          response_body: %{"error" => "too_many_requests"}
        )

      assert error.status == 429
      assert error.reason == "Rate limited"
      assert error.response_body == %{"error" => "too_many_requests"}
      assert Exception.message(error) =~ "429"
      assert Exception.message(error) =~ "Rate limited"
    end

    test "handles nil status" do
      error = API.Request.exception(reason: "Network error")
      assert Exception.message(error) == "API request failed: Network error"
    end

    test "belongs to api class" do
      error = API.Request.exception(reason: "test")
      assert error.class == :api
    end
  end

  describe "API.Response" do
    test "creates error with status and reason" do
      error =
        API.Response.exception(
          reason: "Invalid JSON",
          status: 200,
          response_body: "not json"
        )

      assert error.status == 200
      assert error.reason == "Invalid JSON"
      assert Exception.message(error) =~ "200"
    end

    test "handles nil status" do
      error = API.Response.exception(reason: "Parse error")
      assert Exception.message(error) == "Provider response error: Parse error"
    end

    test "belongs to api class" do
      error = API.Response.exception(reason: "test")
      assert error.class == :api
    end
  end

  describe "API.Stream" do
    test "creates error with reason and cause" do
      cause = %RuntimeError{message: "connection reset"}

      error =
        API.Stream.exception(
          reason: "Stream interrupted",
          cause: cause
        )

      assert error.reason == "Stream interrupted"
      assert error.cause == cause
      assert Exception.message(error) == "Stream interrupted"
    end

    test "belongs to api class" do
      error = API.Stream.exception(reason: "test")
      assert error.class == :api
    end
  end

  describe "Validation.Error" do
    test "creates error with tag, reason, and context" do
      error =
        Validation.Error.exception(
          tag: :invalid_model,
          reason: "Model not found",
          context: [model: "gpt-5"]
        )

      assert error.tag == :invalid_model
      assert error.reason == "Model not found"
      assert error.context == [model: "gpt-5"]
      assert Exception.message(error) == "Model not found"
    end

    test "belongs to validation class" do
      error = Validation.Error.exception(tag: :test, reason: "test")
      assert error.class == :validation
    end
  end

  describe "Unknown.Unknown" do
    test "creates error with error field" do
      error = Unknown.Unknown.exception(error: {:unexpected, :value})
      assert error.error == {:unexpected, :value}
      assert Exception.message(error) =~ "Unknown error"
    end

    test "belongs to unknown class" do
      error = Unknown.Unknown.exception(error: nil)
      assert error.class == :unknown
    end
  end

  describe "validation_error/3" do
    test "creates validation error with tag and context" do
      error = Error.validation_error(:invalid_model, "Bad model", model: "test")
      assert error.tag == :invalid_model
      assert error.reason == "Bad model"
      assert error.context[:model] == "test"
    end

    test "creates validation error with empty context by default" do
      error = Error.validation_error(:missing_key, "API key required")
      assert error.tag == :missing_key
      assert error.reason == "API key required"
      assert error.context == []
    end

    test "returns a Validation.Error struct" do
      error = Error.validation_error(:test, "test reason")
      assert %Validation.Error{} = error
    end
  end
end
