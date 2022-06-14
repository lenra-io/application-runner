defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """
  @behaviour ApplicationRunner.AdapterBehavior

  import Ecto.Query

  alias ApplicationRunner.{
    Data,
    Datastore,
    EnvState,
    Repo,
    SessionState,
    UserData,
    UserDataServices,
    Environment
  }

  alias QueryParser.AST

  use GenServer

  @impl true
  def get_env_and_function_name(env_id) do
    Repo.get(Environment, env_id)
    |> case do
      nil -> {:error, :no_env_found}
      env -> %{environment: env, function_name: "test_#{env_id}"}
    end
  end

  @impl true
  def on_ui_changed(%SessionState{assigns: assigns}, ui_update) do
    case Map.get(assigns, :test_pid, nil) do
      pid when is_pid(pid) ->
        send(pid, ui_update)

      _err ->
        nil
    end

    :ok
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # @impl true
  # def handle_call({:set_mock, mock}, _from, _) do
  #   {:reply, :ok, mock}
  # end

  # @impl true
  # def handle_call({:get_widget, name, data, props}, _from, %{widgets: widgets} = mock) do
  #   case Map.get(widgets, name) do
  #     nil ->
  #       {:reply, {:error, :widget_not_found}, mock}

  #     widget ->
  #       widget = widget.(data, props)
  #       {:reply, {:ok, widget}, mock}
  #   end
  # end

  # def handle_call(
  #       {:run_listener, action, props, event, apiOptions},
  #       _from,
  #       %{listeners: listeners} = mock
  #     ) do
  #   case Map.get(listeners, action) do
  #     nil ->
  #       {:reply, {:error, :listener_not_found}, mock}

  #     listener ->
  #       listener.(props, event, apiOptions)
  #       {:reply, :ok, mock}
  #   end
  # end

  # def handle_call(
  #       {:run_listener, _action, _props, _event},
  #       _from,
  #       mock
  #     ) do
  #   {:reply, :ok, mock}
  # end
end
