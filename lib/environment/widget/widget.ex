defmodule ApplicationRunner.Environment.Widget do
  @moduledoc """
    ApplicationRunner.Environment.Widget get a widget and cache them
  """
  use GenServer

  alias ApplicationRunner.ApplicationServices

  # 10 minutes timeout
  @inactivity_timeout 1000 * 60 * 10

  def get_widget_group(env_id, coll, query) do
    {:widget, env_id, coll, query}
  end

  def start_link(opts) do
    session_state = Keyword.fetch!(opts, :session_state)
    current_widget = Keyword.fetch!(opts, :current_widget)
    name = "#{session_state.env_id}_#{current_widget.name}"

    GenServer.start_link(__MODULE__, opts, name: {:via, :swarm, name})
  end

  @impl true
  def init(opts) do
    session_state = Keyword.fetch!(opts, :session_state)
    current_widget = Keyword.fetch!(opts, :current_widget)

    case ApplicationServices.fetch_widget(
           session_state,
           current_widget.name,
           current_widget.data,
           current_widget.props
         ) do
      {:ok, widget} ->
        state = %{widget_ui: widget, session_state: session_state, current_widget: current_widget}
        {:ok, state, @inactivity_timeout}

      {:error, error} ->
        raise error
    end
  end

  @impl true
  def handle_info({:data_changed, new_data}, state) do
    current_widget = Keyword.fetch!(state, :current_widget)
    session_state = Keyword.fetch!(state, :session_state)

    current_widget_updated = Map.replace(current_widget, :data, new_data)

    case ApplicationServices.fetch_widget(
           session_state,
           current_widget_updated.name,
           current_widget_updated.data,
           current_widget_updated.props
         ) do
      {:ok, widget} ->
        new_state = Keyword.replace(state, :widget_ui, widget)
        {:noreply, new_state}

      {:error, error} ->
        raise error
    end
  end

  @impl true
  def handle_call(:get_widget, _from, state) do
    {:reply, {:ok, Map.get(state, :widget_ui)}, state}
  end
end
