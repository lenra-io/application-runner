defmodule ApplicationRunner.Errors.BusinessError do
  @moduledoc """
    Lenra.Errors.BusinessError handles business errors for the Lenra app.
    This module uses LenraCommon.Errors.BusinessError
  """

  use LenraCommon.Errors.ErrorGenerator,
    module: LenraCommon.Errors.BusinessError,
    inherit: true,
    errors: [
      {:env_not_started, "Environment not stated."},
      {:invalid_token, "Your token is invalid."},
      {:did_not_accept_cgu, "You must accept the CGU to use Lenra"},
      {:unknow_listener_code, "No listeners found for the given code"},
      {:session_not_started, "Session not started"},
      {:json_format_invalid, "JSON format invalid"},
      {:no_app_found, "No application found for the current link"},
      {:invalid_route, "The route is invalid. Maybe a param is missing or badly formatted."}
    ]
end
