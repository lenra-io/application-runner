defmodule ApplicationRunner.AdapterHandler do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  @behaviour ApplicationRunner.AdapterBehavior
  defdelegate get_manifest(env_state),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate get_widget(env_state, widget, data, props),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate run_listener(env_or_session_state, action, props, event),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate exec_query(session_state, query),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate ensure_user_data_created(session_state),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate on_ui_changed(session_state, ui_update),
    to: Application.compile_env!(:application_runner, :adapter)
end
