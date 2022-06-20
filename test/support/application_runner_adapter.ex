defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """

  use GenServer

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def get_widget(_session_state, name, data, props) do
    GenServer.call(__MODULE__, {:get_widget, name, data, props})
  end

  def set_mock(mock) do
    GenServer.call(__MODULE__, {:set_mock, mock})
  end

  @impl true
  def handle_call({:set_mock, mock}, _from, _) do
    {:reply, :ok, mock}
  end

  @impl true
  def handle_call({:get_widget, name, data, props}, _from, %{widgets: widgets} = mock) do
    case Map.get(widgets, name) do
      nil ->
        {:reply, {:error, :widget_not_found}, mock}

      widget ->
        widget = widget.(data, props)
        {:reply, {:ok, widget}, mock}
    end
  end

  def handle_call(
        {:run_listener, action, props, event, apiOptions},
        _from,
        %{listeners: listeners} = mock
      ) do
    case Map.get(listeners, action) do
      nil ->
        {:reply, {:error, :listener_not_found}, mock}

      listener ->
        listener.(props, event, apiOptions)
        {:reply, :ok, mock}
    end
  end

  def handle_call(
        {:run_listener, _action, _props, _event},
        _from,
        mock
      ) do
    {:reply, :ok, mock}
  end
end
