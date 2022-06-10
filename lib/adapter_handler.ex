defmodule ApplicationRunner.AdapterHandler do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  @behaviour ApplicationRunner.AdapterBehavior
  defdelegate get_env_and_function_name(env_id),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate on_ui_changed(session_state, ui_update),
    to: Application.compile_env!(:application_runner, :adapter)
end
