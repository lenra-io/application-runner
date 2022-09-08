defmodule ApplicationRunner.Adapter do
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
end
