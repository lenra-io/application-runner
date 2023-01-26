defmodule ApplicationRunner.ApplicationRunnerAdapter do
  # @moduledoc """
  # Fake ApplicationRunnerAdapter for ApplicationRunner
  # """

  # use GenServer

  # @impl true
  # def init(_) do
  #   {:ok, %{}}
  # end

  # def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # def get_view(_session_state, name, data, props) do
  #   GenServer.call(__MODULE__, {:get_view, name, data, props})
  # end

  # def set_mock(mock) do
  #   GenServer.call(__MODULE__, {:set_mock, mock})
  # end

  # @impl true
  # def handle_call({:set_mock, mock}, _from, _) do
  #   {:reply, :ok, mock}
  # end

  # @impl true
  # def handle_call({:get_view, name, data, props}, _from, %{views: views} = mock) do
  #   case Map.get(views, name) do
  #     nil ->
  #       {:reply, {:error, :view_not_found}, mock}

  #     view ->
  #       view = view.(data, props)
  #       {:reply, {:ok, view}, mock}
  #   end
  # end

  # def handle_call(
  #       {:run_listener, action, props, event, apiOptions},
  #       _from,
  #       %{listeners: listeners} = mock
  #     ) do
  #   case Map.get(listeners, action) do
  #     nil ->
  #       {:reply, {:error, :listener_not_found}, mock}

  #     listener ->
  #       listener.(props, event, apiOptions)
  #       {:reply, :ok, mock}
  #   end
  # end

  # def handle_call(
  #       {:run_listener, _action, _props, _event},
  #       _from,
  #       mock
  #     ) do
  #   {:reply, :ok, mock}
  # end

  @behaviour ApplicationRunner.Adapter

  @impl ApplicationRunner.Adapter
  def allow(_user_id, _app_name) do
    :ok
  end

  @impl ApplicationRunner.Adapter
  def get_function_name(app_name) do
    app_name
  end

  @impl ApplicationRunner.Adapter
  def get_env_id(_app_name) do
    1337
  end

  @impl ApplicationRunner.Adapter
  def resource_from_params(_params) do
    {:ok, 42}
  end

  @impl ApplicationRunner.Adapter
  def send_notification(_notif) do
    :ok
  end
end
