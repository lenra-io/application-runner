defmodule ApplicationRunner.UiCache do
  use GenServer

  alias ApplicationRunner.{SessionManager, SessionState}

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

  def diff_and_save(%SessionState{} = session_state, ui) do
    pid = SessionManager.fetch_module_pid!(session_state, __MODULE__)
    GenServer.call(pid, {:diff_and_save, ui})
  end
end
