defmodule ApplicationRunner.AdapterHandler do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  @behaviour ApplicationRunner.AdapterBehavior

  defdelegate get_manifest(env_state),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate get_widget(env_state, session_state, widget, data, props),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate run_listener(env_state, session_state, action, data, props, event),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate get_data(session_state), to: Application.compile_env!(:application_runner, :adapter)

  defdelegate save_data(session_state, data),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate on_ui_changed(session_state, ui_update),
    to: Application.compile_env!(:application_runner, :adapter)
end
