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

  @manifest %{"entrypoint" => "root"}

  @impl true
  def get_manifest(%EnvState{assigns: assigns}) do
    case assigns do
      %{} -> {:ok, @manifest}
      _ -> {:error, :nothing_bad}
    end
  end

  def manifest_const, do: @manifest

  @impl true
  def get_widget(name, data, props) do
    GenServer.call(__MODULE__, {:get_widget, name, data, props})
  end

  def set_mock(mock) do
    GenServer.call(__MODULE__, {:set_mock, mock})
  end

  @impl true
  def run_listener(%EnvState{}, action, data, props, event) do
    GenServer.call(__MODULE__, {:run_listener, action, data, props, event})
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
  def on_ui_changed(_session_state, ui_update) do
    case ui_update do
      {:ui, ui} ->
        # credo:disable-for-next-line
        IO.inspect(ui)

      {:patches, patches} ->
        # credo:disable-for-next-line
        IO.inspect(patches)
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
  def handle_call({:get_widget, name, data, props}, _from, %{widgets: widgets} = mock) do
    widget = apply(Map.get(widgets, name), [data, props])
    {:reply, {:ok, widget}, mock}
  end

  def handle_call(
        {:run_listener, action, data, props, event},
        _from,
        %{listeners: listeners} = mock
      ) do
    new_data = apply(Map.get(listeners, action), [data, props, event])
    {:reply, new_data, mock}
  end
end
