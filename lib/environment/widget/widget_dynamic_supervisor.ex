defmodule AppicationRunner.Environment.Widget.DynamicSupervisor do
  @moduledoc """
    Environments.Widget.DynamicSupervisor is a supervisor that manage Environment.Widget Genserver
  """
  use DynamicSupervisor

  alias ApplicationRunner.Environment.Widget

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_child_started(session_state, current_widget) do
    name =
      Widget.get_widget_group(session_state.env_id, current_widget.coll, current_widget.query)

    case start_child(session_state, current_widget) do
      {:ok, pid} ->
        Swarm.join(name, pid)
        :ok

      {:error, {:already_started, pid}} ->
        Swarm.join(name, pid)
        :ok

      err ->
        err
    end
  end

  defp start_child(session_state, current_widget) do
    init_value = [session_state: session_state, current_widget: current_widget]

    DynamicSupervisor.start_child(__MODULE__, {Widget, init_value})
  end
end
