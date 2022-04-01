defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """
  @behaviour ApplicationRunner.AdapterBehavior

  alias ApplicationRunner.{EnvState, SessionState}

  use GenServer

  # @root %{
  #   "type" => "flex",
  #   "children" => [
  #     %{"type" => "text", "value" => "foo"},
  #     %{"type" => "widget", "name" => "w1"},
  #     %{"type" => "widget", "name" => "w2"}
  #   ]
  # }
  # @w1 %{"type" => "text", "value" => "bar"}
  # @w2 %{"type" => "button", "text" => "butt", "onPressed" => %{"action" => "inc", "props" => %{}}}

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
  def get_widget(_env_state, session_state, name, data, props) do
    GenServer.call(__MODULE__, {:get_widget, name, data, props, session_state})
  end

  def set_mock(mock) do
    GenServer.call(__MODULE__, {:set_mock, mock})
  end

  @impl true
  def run_listener(%EnvState{}, session_state, action, data, props, event) do
    GenServer.call(__MODULE__, {:run_listener, action, data, props, event, session_state})
  end

  @impl true
  def get_data(%SessionState{session_id: session_id} = _session_state) do
    if :ets.whereis(:data) == :undefined do
      :ets.new(:data, [:named_table, :public])
    end

    case :ets.lookup(:data, session_id) do
      [{_, data}] -> {:ok, data}
      [] -> {:ok, %{}}
    end
  end

  @impl true
  def save_data(%SessionState{session_id: session_id} = _session_state, data) do
    if :ets.whereis(:data) == :undefined do
      :ets.new(:data, [:named_table])
    end

    :ets.insert(:data, {session_id, data})
    :ok
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

  @impl true
  def handle_call({:set_mock, mock}, _from, _) do
    {:reply, :ok, mock}
  end

  @impl true
  def handle_call(
        {:get_widget, name, data, props, _session_state},
        _from,
        %{widgets: widgets} = mock
      ) do
    case Map.get(widgets, name) do
      nil ->
        {:reply, {:error, :widget_not_found}, mock}

      widget ->
        widget = widget.(data, props)
        {:reply, {:ok, widget}, mock}
    end
  end

  def handle_call(
        {:run_listener, action, data, props, event, _session_state},
        _from,
        %{listeners: listeners} = mock
      ) do
    case Map.get(listeners, action) do
      nil ->
        {:reply, {:error, :listener_not_found}, mock}

      listner ->
        new_data = listner.(data, props, event)
        {:reply, {:ok, new_data}, mock}
    end
  end
end
