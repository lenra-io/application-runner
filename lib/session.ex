defmodule ApplicationRunner.Session do
  @moduledoc """
    ApplicationRunner.Session
  """
  defdelegate fetch_token(session_id), to: ApplicationRunner.Session.Token, as: :fetch_token

  defdelegate start_session(session_id, env_id, session_state, env_state),
    to: ApplicationRunner.Session.Managers,
    as: :start_session

  defdelegate send_client_event(session_manager_pid, code, event),
    to: ApplicationRunner.Session.Manager,
    as: :send_client_event
end
