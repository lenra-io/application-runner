defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """

  use GenServer

  @manifest %{"rootWidget" => "root"}

  @impl true
  def get_manifest(%EnvState{assigns: assigns}) do
    case assigns do
      %{} -> {:ok, @manifest}
      _ -> {:error, :nothing_bad}
    end
  end

  def manifest_const, do: @manifest

  @impl true
  def get_widget(_session_state, name, data, props) do
    GenServer.call(__MODULE__, {:get_widget, name, data, props})
  end

  def set_mock(mock) do
    GenServer.call(__MODULE__, {:set_mock, mock})
  end

  @impl true
  def run_listener(%EnvState{assigns: %{environment: env}}, action, props, event) do
    GenServer.call(__MODULE__, {:run_listener, action, props, event, %{env_id: env.id}})
  end

  def run_listener(%SessionState{assigns: %{environment: env, user: user}}, action, props, event) do
    user_data_id = get_user_data_id(env, user)

    GenServer.call(
      __MODULE__,
      {
        :run_listener,
        action,
        props,
        event,
        %{env_id: env.id, user_data_id: user_data_id}
      }
    )
  end

  def run_listener(_state, _action, _props, _event) do
    :ok
  end

  defp get_user_data_id(env, user) do
    from(ud in UserData,
      join: d in Data,
      on: ud.data_id == d.id,
      join: ds in Datastore,
      on: d.datastore_id == ds.id,
      where: ud.user_id == ^user.id and ds.environment_id == ^env.id,
      select: ud.data_id
    )
    |> Repo.one()
  end

  @impl true
  def exec_query(
        %SessionState{assigns: %{environment: environment, user: user}},
        query
      ) do
    user_data_id = get_user_data_id(environment, user)

    query
    |> AST.EctoParser.to_ecto(environment.id, user_data_id)
    |> Repo.all()
  end

  @impl true
  def create_user_data(%SessionState{assigns: %{environment: environment, user: user}}) do
    UserDataServices.create_with_data(environment.id, user.id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      _err ->
        {:error, :unable_to_create_user_data}
    end
  end

  def create_user_data(_session_state) do
    :ok
  end

  @impl true
  def first_time_user?(%SessionState{assigns: %{environment: environment, user: user}}) do
    UserDataServices.current_user_data_query(environment.id, user.id)
    |> Repo.exists?()
  end

  def first_time_user?(_), do: false

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

  def get_widget(_session_state, name, data, props) do
    GenServer.call(__MODULE__, {:get_widget, name, data, props})
  end

  def set_mock(mock) do
    GenServer.call(__MODULE__, {:set_mock, mock})
  end

  @impl true
  def handle_call({:set_mock, mock}, _from, _) do
    {:reply, :ok, mock}
  end

  @impl true
  def handle_call({:get_widget, name, data, props}, _from, %{widgets: widgets} = mock) do
    case Map.get(widgets, name) do
      nil ->
        {:reply, {:error, :widget_not_found}, mock}

      widget ->
        widget = widget.(data, props)
        {:reply, {:ok, widget}, mock}
    end
  end

  def handle_call(
        {:run_listener, action, props, event, apiOptions},
        _from,
        %{listeners: listeners} = mock
      ) do
    case Map.get(listeners, action) do
      nil ->
        {:reply, {:error, :listener_not_found}, mock}

      listener ->
        listener.(props, event, apiOptions)
        {:reply, :ok, mock}
    end
  end

  def handle_call(
        {:run_listener, _action, _props, _event},
        _from,
        mock
      ) do
    {:reply, :ok, mock}
  end
end
