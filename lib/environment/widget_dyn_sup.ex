defmodule ApplicationRunner.Environment.WidgetDynSup do
  @moduledoc """
    Environment.Widget.DynamicSupervisor is a supervisor that manages Environment.Widget Genserver
  """
  use DynamicSupervisor
  use SwarmNamed

  alias ApplicationRunner.Environment
  alias ApplicationRunner.Environment.WidgetServer

  def start_link(%Environment.Metadata{} = env_metadata) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: get_full_name(env_metadata.env_id))
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_child_started(session_metadata, current_widget) do
    group_name =
      WidgetServer.get_group(
        session_metadata.env_id,
        current_widget.coll,
        current_widget.query
      )

    case start_child(session_metadata, current_widget) do
      {:ok, pid} ->
        Swarm.join(group_name, pid)
        :ok

      {:error, {:already_started, pid}} ->
        Swarm.join(group_name, pid)
        :ok

      err ->
        err
    end
  end

  defp start_child(session_metadata, current_widget) do
    init_value = [session_metadata: session_metadata, current_widget: current_widget]

    DynamicSupervisor.start_child(
      get_full_name(session_metadata.env_id),
      {WidgetServer, init_value}
    )
  end
end
