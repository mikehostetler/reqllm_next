defmodule ReqLlmNext.Error do
  @moduledoc """
  Error handling system for ReqLlmNext using Splode.
  """

  use Splode,
    error_classes: [
      invalid: ReqLlmNext.Error.Invalid,
      api: ReqLlmNext.Error.API,
      validation: ReqLlmNext.Error.Validation,
      unknown: ReqLlmNext.Error.Unknown
    ],
    unknown_error: ReqLlmNext.Error.Unknown.Unknown

  defmodule Invalid do
    @moduledoc "Error class for invalid input parameters and configurations."
    use Splode.ErrorClass, class: :invalid
  end

  defmodule API do
    @moduledoc "Error class for API-related failures and HTTP errors."
    use Splode.ErrorClass, class: :api
  end

  defmodule Validation do
    @moduledoc "Error class for validation failures and parameter errors."
    use Splode.ErrorClass, class: :validation
  end

  defmodule Unknown do
    @moduledoc "Error class for unexpected or unhandled errors."
    use Splode.ErrorClass, class: :unknown
  end

  defmodule Invalid.Parameter do
    @moduledoc "Error for invalid or missing parameters."
    use Splode.Error, fields: [:parameter], class: :invalid

    @spec message(map()) :: String.t()
    def message(%{parameter: parameter}) do
      "Invalid parameter: #{parameter}"
    end
  end

  defmodule Invalid.Provider do
    @moduledoc "Error for unknown or unsupported providers."
    use Splode.Error, fields: [:provider, :message], class: :invalid

    @typedoc "Error for unknown provider"
    @type t() :: %__MODULE__{
            message: String.t(),
            provider: atom()
          }

    @spec message(map()) :: String.t()
    def message(%{message: msg}) when is_binary(msg), do: msg

    def message(%{provider: provider}) do
      "Unknown provider: #{provider}"
    end
  end

  defmodule Invalid.Capability do
    @moduledoc "Error for unsupported model capabilities."
    use Splode.Error, fields: [:message, :missing], class: :invalid

    @spec message(map()) :: String.t()
    def message(%{message: msg}) when is_binary(msg), do: msg

    def message(%{missing: missing}) do
      "Unsupported capabilities: #{inspect(missing)}"
    end
  end

  defmodule API.Request do
    @moduledoc "Error for API request failures, HTTP errors, and network issues."
    use Splode.Error,
      fields: [:reason, :status, :response_body],
      class: :api

    @spec message(map()) :: String.t()
    def message(%{reason: reason, status: status}) when not is_nil(status) do
      "API request failed (#{status}): #{reason}"
    end

    def message(%{reason: reason}) do
      "API request failed: #{reason}"
    end
  end

  defmodule API.Response do
    @moduledoc "Error for provider response parsing failures and unexpected response formats."
    use Splode.Error,
      fields: [:reason, :response_body, :status],
      class: :api

    @spec message(map()) :: String.t()
    def message(%{reason: reason, status: status}) when not is_nil(status) do
      "Provider response error (#{status}): #{reason}"
    end

    def message(%{reason: reason}) do
      "Provider response error: #{reason}"
    end
  end

  defmodule API.Stream do
    @moduledoc "Error for stream processing failures."
    use Splode.Error,
      fields: [:reason, :cause],
      class: :api

    @spec message(map()) :: String.t()
    def message(%{reason: reason}) do
      reason
    end
  end

  defmodule API.SchemaValidation do
    @moduledoc "Error for schema validation failures."
    use Splode.Error,
      fields: [:message, :errors, :json_path, :value],
      class: :api

    @spec message(map()) :: String.t()
    def message(%{message: message}) when is_binary(message), do: message

    def message(%{errors: errors}) when is_list(errors),
      do: "Schema validation failed: #{inspect(errors)}"

    def message(_), do: "Schema validation failed"
  end

  defmodule API.JsonParse do
    @moduledoc "Error for JSON parsing failures."
    use Splode.Error,
      fields: [:message, :raw_json],
      class: :api

    @spec message(map()) :: String.t()
    def message(%{message: message}) when is_binary(message), do: message
    def message(_), do: "Failed to parse JSON response"
  end

  defmodule Validation.Error do
    @moduledoc "Error for parameter validation failures."
    use Splode.Error,
      fields: [:tag, :reason, :context],
      class: :validation

    @typedoc "Validation error returned by ReqLlmNext"
    @type t() :: %__MODULE__{
            tag: atom(),
            reason: String.t(),
            context: keyword()
          }

    @spec message(map()) :: String.t()
    def message(%{reason: reason}) do
      reason
    end
  end

  defmodule Unknown.Unknown do
    @moduledoc "Error for unexpected or unhandled errors."
    use Splode.Error, fields: [:error], class: :unknown

    @spec message(map()) :: String.t()
    def message(%{error: error}) do
      "Unknown error: #{inspect(error)}"
    end
  end

  @doc """
  Creates a validation error with the given tag, reason, and context.

  ## Examples

      iex> error = ReqLlmNext.Error.validation_error(:invalid_model_spec, "Bad model", model: "test")
      iex> error.tag
      :invalid_model_spec
      iex> error.reason
      "Bad model"
      iex> error.context
      [model: "test"]

  """
  @spec validation_error(atom(), String.t(), keyword()) :: ReqLlmNext.Error.Validation.Error.t()
  def validation_error(tag, reason, context \\ []) do
    ReqLlmNext.Error.Validation.Error.exception(tag: tag, reason: reason, context: context)
  end
end
