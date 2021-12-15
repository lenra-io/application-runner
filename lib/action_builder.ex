defmodule ApplicationRunner.ActionBuilder do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  alias ApplicationRunner.{SessionState, WidgetContext, UIValidator, UiContext}

  @spec first_run(SessionState.t()) :: {:ok, map()} | {:error, any()}

  @doc """
    This function build the first UI with default Entry Point `"InitData"` to generate the data model and `"MainUi"` to generate the UI
  """
  def first_run(session_state) do
    {:ok, %{"entrypoint" => entrypoint}} = get_manifest(session_state)

    uuid = UUID.uuid1()

    {:ok, ui_context} =
      UIValidator.get_and_build_widget(
        session_state,
        %UiContext{
          widgets_map: %{},
          listeners_map: %{}
        },
        %WidgetContext{
          id: uuid,
          name: entrypoint
        }
      )

    {:ok, %{"entrypoint" => entrypoint, "widgets" => ui_context.widgets_map}}
  end

  @behaviour ApplicationRunner.AdapterBehavior
  defdelegate get_manifest(app),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate get_widget(app, widget, data),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate run_listener(app, listener, data),
    to: Application.compile_env!(:application_runner, :adapter)

  defdelegate get_data(session_state), to: Application.compile_env!(:application_runner, :adapter)

  defdelegate save_data(session_state, data),
    to: Application.compile_env!(:application_runner, :adapter)
end
