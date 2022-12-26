defmodule ApplicationRunner.Environment.WidgetServer do
  @moduledoc """
    ApplicationRunner.Environment.Widget get a widget and cache them
  """
  use GenServer
  use SwarmNamed

  alias ApplicationRunner.ApplicationServices
  alias ApplicationRunner.Environment.{QueryServer, WidgetUid}

  # 10 minutes timeout
  @inactivity_timeout 1000 * 60 * 10

  def group_name(env_id, coll, query) do
    {__MODULE__, env_id, coll, query}
  end

  def join_group(pid, env_id, coll, query) do
    group = group_name(env_id, coll, query)
    Swarm.join(group, pid)
  end

  @spec fetch_widget!(any, WidgetUid.t()) :: map()
  def fetch_widget!(env_id, widget_uid) do
    filtered_widget_uid = Map.filter(widget_uid, fn {key, _value} -> key != :prefix_path end)

    GenServer.call(get_full_name({env_id, filtered_widget_uid}), :fetch_widget!)
  end

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    widget_uid = Keyword.fetch!(opts, :widget_uid)

    filtered_widget_uid = Map.filter(widget_uid, fn {key, _value} -> key != :prefix_path end)

    GenServer.start_link(__MODULE__, opts, name: get_full_name({env_id, filtered_widget_uid}))
  end

  @impl true
  def init(opts) do
    function_name = Keyword.fetch!(opts, :function_name)
    env_id = Keyword.fetch!(opts, :env_id)
    %WidgetUid{} = widget_uid = Keyword.fetch!(opts, :widget_uid)

    with data <- QueryServer.get_data(env_id, widget_uid.coll, widget_uid.query_parsed),
         {:ok, widget} <-
           ApplicationServices.fetch_widget(
             function_name,
             widget_uid.name,
             data,
             widget_uid.props,
             widget_uid.context
           ) do
      state = %{
        widget: widget,
        function_name: function_name,
        widget_uid: widget_uid
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
    wuid = Map.fetch!(state, :widget_uid)

    case ApplicationServices.fetch_widget(fna, wuid.name, new_data, wuid.props, wuid.context) do
      {:ok, widget} ->
        {:noreply, Map.put(state, :widget, widget), @inactivity_timeout}

      {:error, error} ->
        raise error
    end
  end

  @impl true
  def handle_call(:fetch_widget!, _from, state) do
    {:reply, Map.fetch!(state, :widget), state, @inactivity_timeout}
  end
end
