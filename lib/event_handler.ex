defmodule ApplicationRunner.EventHandler do
  @moduledoc """
    This EventHandler genserver handle and run all the listener events.
  """
  use GenServer
  use SwarmNamed

  alias ApplicationRunner.ApplicationServices
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Session

  require Logger

  #########
  ## API ##
  #########

  @doc """
    Send async call to application,
    the call will run listeners with the given `action` `props` `event`
  """
  def send_env_event(env_id, action, props, event) do
    GenServer.call(
      get_full_name({:env, env_id}),
      {:send_event, action, props, event, env_id},
      Application.fetch_env!(:application_runner, :listeners_timeout)
    )
  end

  def send_session_event(session_id, action, props, event) do
    GenServer.call(
      get_full_name({:session, session_id}),
      {:send_event, action, props, event, session_id},
      Application.fetch_env!(:application_runner, :listeners_timeout)
    )
  end

  def send_client_event(session_id, code, event) do
    with {:ok, listener} <- Session.ListenersCache.fetch_listener(session_id, code),
         {:ok, action} <- Map.fetch(listener, "action"),
         props <- Map.get(listener, "props", %{}) do
      send_session_event(session_id, action, props, event)
    end
  end

  ###############
  ## Callbacks ##
  ###############

  def start_link(opts) do
    Logger.notice("Start #{__MODULE__}")
    Logger.debug("#{__MODULE__} start_link with opts #{inspect(opts)}")

    mode = Keyword.fetch!(opts, :mode)
    id = Keyword.fetch!(opts, :id)

    GenServer.start_link(__MODULE__, %{id: id, mode: mode}, name: get_full_name({mode, id}))
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(
        {:send_event, "@lenra:" <> action, props, event, session_id},
        _from,
        state
      ) do
    Logger.debug(
      "#{__MODULE__} handle_call for @lenra action: #{inspect(action)} with props #{inspect(props)} and event #{inspect(event)}"
    )

    case action do
      "navTo" ->
        ApplicationRunner.RoutesChannel.get_name(session_id)
        |> Swarm.send({:send, :navTo, props})
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(
        {:send_event, action, props, event, _session_id},
        _from,
        %{mode: mode, id: id} = state
      ) do
    Logger.debug(
      "#{__MODULE__} handle_call for action: #{inspect(action)} with props #{inspect(props)} and event #{inspect(event)}"
    )

    %{function_name: function_name, token: token} = get_metadata(mode, id)
    res = ApplicationServices.run_listener(function_name, action, props, event, token)

    {:reply, res, state}
  end

  defp get_metadata(:session, session_id) do
    Session.MetadataAgent.get_metadata(session_id)
  end

  defp get_metadata(:env, env_id) do
    Environment.MetadataAgent.get_metadata(env_id)
  end
end
