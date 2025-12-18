defmodule ReqLlmNext.ErrorTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Error
  alias ReqLlmNext.Error.API
  alias ReqLlmNext.Error.Invalid
  alias ReqLlmNext.Error.Unknown
  alias ReqLlmNext.Error.Validation

  describe "Error.Invalid error class" do
    test "is a valid Splode error class" do
      assert Invalid.__struct__().class == :invalid
    end

    test "can wrap child errors" do
      child = Invalid.Parameter.exception(parameter: "test")
      wrapper = Invalid.exception(errors: [child])

      assert wrapper.class == :invalid
      assert length(wrapper.errors) == 1
    end

    test "can be raised and caught" do
      assert_raise Invalid, fn ->
        raise Invalid.exception(errors: [])
      end
    end

    test "implements Exception behaviour" do
      wrapper = Invalid.exception(errors: [])
      assert Exception.message(wrapper) =~ ""
    end
  end

  describe "Error.API error class" do
    test "is a valid Splode error class" do
      assert API.__struct__().class == :api
    end

    test "can wrap child errors" do
      child = API.Request.exception(reason: "timeout")
      wrapper = API.exception(errors: [child])

      assert wrapper.class == :api
      assert length(wrapper.errors) == 1
    end

    test "can be raised and caught" do
      assert_raise API, fn ->
        raise API.exception(errors: [])
      end
    end

    test "implements Exception behaviour" do
      wrapper = API.exception(errors: [])
      assert Exception.message(wrapper) =~ ""
    end
  end

  describe "Error.Validation error class" do
    test "is a valid Splode error class" do
      assert Validation.__struct__().class == :validation
    end

    test "can wrap child errors" do
      child = Validation.Error.exception(tag: :test, reason: "invalid")
      wrapper = Validation.exception(errors: [child])

      assert wrapper.class == :validation
      assert length(wrapper.errors) == 1
    end

    test "can be raised and caught" do
      assert_raise Validation, fn ->
        raise Validation.exception(errors: [])
      end
    end

    test "implements Exception behaviour" do
      wrapper = Validation.exception(errors: [])
      assert Exception.message(wrapper) =~ ""
    end
  end

  describe "Error.Unknown error class" do
    test "is a valid Splode error class" do
      assert Unknown.__struct__().class == :unknown
    end

    test "can wrap child errors" do
      child = Unknown.Unknown.exception(error: :unexpected)
      wrapper = Unknown.exception(errors: [child])

      assert wrapper.class == :unknown
      assert length(wrapper.errors) == 1
    end

    test "can be raised and caught" do
      assert_raise Unknown, fn ->
        raise Unknown.exception(errors: [])
      end
    end

    test "implements Exception behaviour" do
      wrapper = Unknown.exception(errors: [])
      assert Exception.message(wrapper) =~ ""
    end
  end

  describe "Splode integration" do
    test "Error.to_class/1 converts errors to class wrappers" do
      child = API.Request.exception(reason: "failed")
      result = Error.to_class(child)

      assert %API{} = result
      assert result.class == :api
    end

    test "Error.to_class/1 wraps unknown errors" do
      result = Error.to_class(%RuntimeError{message: "boom"})

      assert %Unknown{} = result
    end
  end

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

  describe "API.SchemaValidation" do
    test "message/1 with message field returns the message" do
      error = API.SchemaValidation.exception(message: "Custom validation error")
      assert Exception.message(error) == "Custom validation error"
    end

    test "message/1 with errors list returns formatted errors" do
      error = API.SchemaValidation.exception(errors: ["field1 is invalid", "field2 is required"])
      msg = Exception.message(error)
      assert msg =~ "Schema validation failed"
      assert msg =~ "field1 is invalid"
    end

    test "message/1 without message or errors returns default message" do
      error = API.SchemaValidation.exception(json_path: "/data/field", value: "bad")
      assert Exception.message(error) == "Schema validation failed"
    end

    test "includes all fields" do
      error =
        API.SchemaValidation.exception(
          message: "Invalid",
          errors: ["error1"],
          json_path: "/path",
          value: %{test: true}
        )

      assert error.message == "Invalid"
      assert error.errors == ["error1"]
      assert error.json_path == "/path"
      assert error.value == %{test: true}
    end

    test "can be raised and caught" do
      assert_raise API.SchemaValidation, fn ->
        raise API.SchemaValidation.exception(message: "test error")
      end
    end

    test "belongs to api class" do
      error = API.SchemaValidation.exception(message: "test")
      assert error.class == :api
    end
  end

  describe "API.JsonParse" do
    test "message/1 with message field returns the message" do
      error = API.JsonParse.exception(message: "Unexpected token at position 5")
      assert Exception.message(error) == "Unexpected token at position 5"
    end

    test "message/1 without message returns default message" do
      error = API.JsonParse.exception(raw_json: "{invalid json}")
      assert Exception.message(error) == "Failed to parse JSON response"
    end

    test "includes raw_json field" do
      raw = ~s({"broken": )
      error = API.JsonParse.exception(message: "Parse error", raw_json: raw)
      assert error.raw_json == raw
    end

    test "can be raised and caught" do
      assert_raise API.JsonParse, fn ->
        raise API.JsonParse.exception(message: "JSON parse error")
      end
    end

    test "belongs to api class" do
      error = API.JsonParse.exception(raw_json: "bad")
      assert error.class == :api
    end
  end
end
