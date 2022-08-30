defmodule ApplicationRunner.Session.Supervisor do
  @moduledoc """
    This Supervisor is started by the SessionManager.
    It handle all the GenServer needed for the Session to work.
  """
  use Supervisor
  use SwarmNamed

  alias ApplicationRunner.Session

  def start_link(%Session.Metadata{} = session_metadata) do
    Supervisor.start_link(__MODULE__, session_metadata,
      name: get_full_name(session_metadata.session_id)
    )
  end

  @impl true
  def init(%Session.Metadata{} = session_metadata) do
    children = [
      # TODO: add module once they done !
      {ApplicationRunner.Session.MetadataAgent, session_metadata},
      # {ApplicationRunner.Session.Token.Agent, opts}
      {Session.ListenersCache, session_id: session_metadata.session_id},
      {Session.ChangeEventManager,
       env_id: session_metadata.env_id, session_id: session_metadata.session_id},
      # ApplicationRunner.EventHandler
      # Event.OnUserFirstJoin
      {Session.Task.OnSessionStart,
       token: session_metadata.token, function_name: session_metadata.function_name},
      {Session.Task.OnUserFirstJoin,
       [
         session_metadata.env_id,
         session_metadata.user_id,
         session_metadata.token,
         session_metadata.function_name
       ]},
      # Event.OnSessionStart
      {Session.UiServer, session_id: session_metadata.session_id}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
