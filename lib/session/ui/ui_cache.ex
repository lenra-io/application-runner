defmodule ApplicationRunner.Ui.Cache do
  @moduledoc """
    This is the UI Cache module.
    This cache is started by the SessionSupervisor. It contain the current state of the UI.
    If the current ui state is empty, UiCache save the new ui state and return the full state.
    If the current ui state already exists, UiCache save the new UI and return the diff JSON Patch between old and new UI state.
  """
  use GenServer

  alias ApplicationRunner.Session.{State, Supervisor}

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def init(:ok) do
    {:ok, :none}
  end

  def handle_call({:diff_and_save, ui}, _from, old_ui) do
    case old_ui do
      :none ->
        {:reply, {:ui, ui}, ui}

      _ ->
        patches = JSONDiff.diff(old_ui, ui)
        {:reply, {:patches, patches}, ui}
    end
  end

  def diff_and_save(%State{} = session_state, ui) do
    pid = Supervisor.fetch_module_pid!(session_state.session_supervisor_pid, __MODULE__)
    GenServer.call(pid, {:diff_and_save, ui})
  end
end
