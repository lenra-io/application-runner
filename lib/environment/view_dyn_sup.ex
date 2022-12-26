defmodule ApplicationRunner.Environment.ViewDynSup do
  @moduledoc """
    Environment.View.DynamicSupervisor is a supervisor that manages Environment.View Genserver
  """
  use DynamicSupervisor
  use SwarmNamed

  alias ApplicationRunner.Environment.{QueryDynSup, QueryServer, ViewServer, ViewUid}

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    DynamicSupervisor.start_link(__MODULE__, :ok, name: get_full_name(env_id))
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec ensure_child_started(number(), any(), String.t(), ViewUid.t()) ::
          {:error, any} | {:ok, pid}
  def ensure_child_started(env_id, session_id, function_name, %ViewUid{} = view_uid) do
    coll = view_uid.coll
    query_parsed = view_uid.query_parsed
    query_transformed = view_uid.query_transformed

    with {:ok, qs_pid} <-
           QueryDynSup.ensure_child_started(env_id, coll, query_parsed, query_transformed) do
      case start_child(env_id, function_name, view_uid) do
        {:ok, pid} ->
          QueryServer.join_group(qs_pid, session_id)
          ViewServer.join_group(pid, env_id, coll, query_parsed)
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

  defp start_child(env_id, function_name, view_uid) do
    init_value = [env_id: env_id, function_name: function_name, view_uid: view_uid]

    DynamicSupervisor.start_child(
      get_full_name(env_id),
      {ViewServer, init_value}
    )
  end
end
