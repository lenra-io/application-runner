defmodule ApplicationRunner.Adapter do
  alias ApplicationRunner.Notifications.Notif

  @moduledoc """
  ApplicationRunner.Adapter provides a callback for a different implementation depending on the parent application
  """

  @doc """
    Implement this function to allow user or not according to the server/devtools needs
  """
  @callback allow(number(), String.t()) :: :ok | {:error, any()}

  @doc """
    Override this function to return the function name according to the server/devtools needs
  """
  @callback get_function_name(String.t()) :: String.t()

  @doc """
    Override this function to return the environment id from the app_name to the server/devtools needs
  """
  @callback get_env_id(String.t()) :: number()

  @callback resource_from_params(map()) :: {:ok, number} | {:error, any()}

  @doc """
    Send the notification to a specific user using the correct technique (UnifiedPush, FCM, APNS...)
  """
  @callback send_notification(Notif.t()) :: :ok | {:error, any()}
end
