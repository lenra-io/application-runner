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
      {:not_an_object_id, "The given id is not a valid object id"},
      {:incorrect_view_mode, "The view mode should be one of 'lenra', 'json'."},
      {:no_action_in_listener, "Your listener does not have the required property 'action'"},
      {:route_does_not_exist, "The given route does not exist. Please check your manifest."},
      {:invalid_channel_name, "The given channel name does not exist."}
    ]
end
