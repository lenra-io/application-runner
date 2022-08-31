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
  def init(%Session.Metadata{} = sm) do
    children = [
      # TODO: add module once they done !
      {ApplicationRunner.Session.MetadataAgent, sm},
      {ApplicationRunner.EventHandler, mode: :session, id: sm.session_id},
      {Session.Task.OnUserFirstJoin,
       session_id: sm.session_id, env_id: sm.env_id, user_id: sm.user_id},
      {Session.Task.OnSessionStart, session_id: sm.session_id},
      {Session.ListenersCache, session_id: sm.session_id},
      {Session.ChangeEventManager, env_id: sm.env_id, session_id: sm.session_id},
      {Session.UiServer, session_id: sm.session_id}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
