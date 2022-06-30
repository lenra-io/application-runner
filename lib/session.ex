defmodule ApplicationRunner.Session do
  @moduledoc """
    ApplicationRunner.Session manage all lenra session fonctionnality
  """

  @doc """
    Fecth the current token for the given `session_id`.

    Returns UUID.
  """
  defdelegate fetch_token(session_id), to: ApplicationRunner.Session.Token, as: :fetch_token

  @doc """
    Start a Session GenServer for the given `session_id` (must be unique),
    with the given session_state.
    Make sure the environment Genserver is started for the given `env_id`,
    if the environment is not started, it is started with the given `env_state`.

    Returns {:ok, session_pid} | {:error, tuple()}
  """
  defdelegate start_session(session_id, env_id, session_state, env_state),
    to: ApplicationRunner.Session.Managers,
    as: :start_session

  @doc """
    Send an async call to the application,
    The call will run listners for the given code `code` ans `event`

    Returns :ok
  """
  defdelegate send_client_event(session_manager_pid, code, event),
    to: ApplicationRunner.Session.Manager,
    as: :send_client_event
end
