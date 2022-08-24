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
      {Session.ChangeEventManager,
       env_id: session_metadata.env_id, session_id: session_metadata.session_id}
      # ApplicationRunner.EventHandler
      # Event.OnUserFirstJoin
      # Event.OnSessionStart
      # UiBuilder
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
