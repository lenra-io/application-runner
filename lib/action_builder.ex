defmodule ApplicationRunner.ActionBuilder do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  alias ApplicationRunner.{AppContext, WidgetContext, UIValidator}

  @spec first_run(AppContext.t()) :: {:ok, map()} | {:error, any()}

  @doc """
    This function build the first UI with default Entry Point `"InitData"` to generate the data model and `"MainUi"` to generate the UI
  """
  def first_run(%AppContext{} = app_context) do
    {:ok, %{"entrypoint" => entrypoint}} = get_manifest(app_context)

    uuid = UUID.uuid1()
    {:ok, app_context} = UIValidator.get_and_build_widget(Map.put(app_context, :entrypoint, uuid), %WidgetContext{
      widget_id: uuid,
      widget_name: entrypoint
    })
    {:ok, %{"entrypoint" => app_context.entrypoint, "widgets" => app_context.widgets_map}}
  end

  @behaviour ApplicationRunner.AdapterBehavior
  defdelegate get_manifest(app),
    to: Application.fetch_env!(:application_runner, :adapter)

  defdelegate get_widget(app, widget, data),
    to: Application.fetch_env!(:application_runner, :adapter)

  defdelegate run_listener(app, listener, data),
      to: Application.fetch_env!(:application_runner, :adapter)

  defdelegate get_data(action), to: Application.fetch_env!(:application_runner, :adapter)
  defdelegate save_data(action, data), to: Application.fetch_env!(:application_runner, :adapter)
end
