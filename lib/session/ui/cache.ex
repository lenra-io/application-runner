defmodule ApplicationRunner.Ui.Cache do
  @moduledoc """
    This is the UI Cache module.
    This cache is started by the SessionSupervisor. It contain the current state of the UI.
    If the current ui state is empty, UiCache save the new ui state and return the full state.
    If the current ui state already exists, UiCache save the new UI and return the diff JSON Patch between old and new UI state.
  """
  use GenServer
  use SwarmNamed

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, :ok, name: get_full_name(session_id))
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

  def diff_and_save(session_id, ui) do
    GenServer.call(get_full_name(session_id), {:diff_and_save, ui})
  end
end
