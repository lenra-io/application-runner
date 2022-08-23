defmodule ApplicationRunner.Session.MetadataAgent do
  @moduledoc """
    ApplicationRunner.Session.TokenAgent manages token for session api request
  """
  use Agent
  use SwarmNamed

  alias ApplicationRunner.Session

  def start_link(%Session.Metadata{} = session_metadata) do
    Agent.start_link(fn -> session_metadata end, name: get_full_name(session_metadata.session_id))
  end

  def fetch_token(session_id) do
    Agent.get(
      get_full_name(session_id),
      fn %Session.Metadata{} = session_metadata ->
        session_metadata.token
      end
    )
  end
end
