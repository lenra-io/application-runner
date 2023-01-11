defmodule ApplicationRunner.Environment.ViewServer do
  @moduledoc """
    ApplicationRunner.Environment.View get a View and cache them
  """
  use GenServer
  use SwarmNamed

  alias ApplicationRunner.ApplicationServices
  alias ApplicationRunner.Environment.{QueryServer, ViewUid}

  # 10 minutes timeout
  @inactivity_timeout 1000 * 60 * 10

  def group_name(env_id, coll, query) do
    {__MODULE__, env_id, coll, query}
  end

  def join_group(pid, env_id, coll, query) do
    group = group_name(env_id, coll, query)
    Swarm.join(group, pid)
  end

  @spec fetch_view!(any, ViewUid.t()) :: map()
  def fetch_view!(env_id, view_uid) do
    filtered_view_uid = Map.filter(view_uid, fn {key, _value} -> key != :prefix_path end)

    GenServer.call(get_full_name({env_id, filtered_view_uid}), :fetch_view!)
  end

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    view_uid = Keyword.fetch!(opts, :view_uid)

    filtered_view_uid = Map.filter(view_uid, fn {key, _value} -> key != :prefix_path end)

    GenServer.start_link(__MODULE__, opts, name: get_full_name({env_id, filtered_view_uid}))
  end

  @impl true
  def init(opts) do
    function_name = Keyword.fetch!(opts, :function_name)
    env_id = Keyword.fetch!(opts, :env_id)
    %ViewUid{} = view_uid = Keyword.fetch!(opts, :view_uid)

    with data <- QueryServer.get_data(env_id, view_uid.coll, view_uid.query_parsed),
         {:ok, view} <-
           ApplicationServices.fetch_view(
             function_name,
             view_uid.name,
             data,
             view_uid.props,
             view_uid.context
           ) do
      state = %{
        view: view,
        function_name: function_name,
        view_uid: view_uid
      }

      {:ok, state, @inactivity_timeout}
    else
      {:error, error} ->
        {:stop, error}
    end
  end

  @impl true
  def handle_info({:data_changed, new_data}, state) do
    fna = Map.fetch!(state, :function_name)
    wuid = Map.fetch!(state, :view_uid)

    case ApplicationServices.fetch_view(fna, wuid.name, new_data, wuid.props, wuid.context) do
      {:ok, view} ->
        {:noreply, Map.put(state, :view, view), @inactivity_timeout}

      {:error, error} ->
        raise error
    end
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:fetch_view!, _from, state) do
    {:reply, Map.fetch!(state, :view), state, @inactivity_timeout}
  end
end
