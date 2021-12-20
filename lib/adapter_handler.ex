defmodule ApplicationRunner.AdapterHandler do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  @behaviour ApplicationRunner.AdapterBehavior
  defdelegate get_manifest(app),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate get_widget(app, widget, data),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate run_listener(app, listener, data),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate get_data(env_state), to: Application.compile_env!(:application_runner, :adapter)

  defdelegate save_data(env_state, data),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate on_ui_changed(ui), to: Application.compile_env!(:application_runner, :adapter)
end
