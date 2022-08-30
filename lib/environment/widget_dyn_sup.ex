defmodule ApplicationRunner.Environment.WidgetDynSup do
  @moduledoc """
    Environment.Widget.DynamicSupervisor is a supervisor that manages Environment.Widget Genserver
  """
  use DynamicSupervisor
  use SwarmNamed

  alias ApplicationRunner.Environment.{QueryDynSup, QueryServer, WidgetServer, WidgetUid}

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    DynamicSupervisor.start_link(__MODULE__, :ok, name: get_full_name(env_id))
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec ensure_child_started(number(), any(), String.t(), WidgetUid.t()) ::
          {:error, any} | {:ok, pid}
  def ensure_child_started(env_id, session_id, function_name, %WidgetUid{} = widget_uid) do
    coll = widget_uid.coll
    query = widget_uid.query

    with {:ok, qs_pid} <- QueryDynSup.ensure_child_started(env_id, coll, query) do
      case start_child(env_id, function_name, widget_uid) do
        {:ok, pid} ->
          QueryServer.join_group(qs_pid, session_id)
          WidgetServer.join_group(pid, env_id, coll, query)
          QueryServer.monitor(qs_pid, pid)
          {:ok, pid}

        {:error, {:already_started, pid}} ->
          QueryServer.join_group(qs_pid, session_id)
          {:ok, pid}

        err ->
          err
      end
    end
  end

  defp start_child(env_id, function_name, widget_uid) do
    init_value = [env_id: env_id, function_name: function_name, widget_uid: widget_uid]

    DynamicSupervisor.start_child(
      get_full_name(env_id),
      {WidgetServer, init_value}
    )
  end
end
