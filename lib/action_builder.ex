defmodule ApplicationRunner.ActionBuilder do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  alias ApplicationRunner.{AppContext, WidgetContext, UIValidator}

  @spec first_run(AppContext.t()) :: {:ok, AppContext.t()} | {:error, any()}

  @doc """
    This function build the first UI with default Entry Point `"InitData"` to generate the data model and `"MainUi"` to generate the UI
  """
  def first_run(%AppContext{} = app_context) do
    UIValidator.get_and_build_widget(app_context, %WidgetContext{
      widget_name: "root",
      prefix_path: "/"
    })
  end

  @behaviour ApplicationRunner.AdapterBehavior
  defdelegate run_action(action),
    to: Application.fetch_env!(:application_runner, :adapter)

  defdelegate get_data(action), to: Application.fetch_env!(:application_runner, :adapter)
  defdelegate save_data(action, data), to: Application.fetch_env!(:application_runner, :adapter)
end
