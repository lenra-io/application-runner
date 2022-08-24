defmodule ApplicationRunner.Session do
  @moduledoc """
    ApplicationRunner.Session manage all lenra session fonctionnality
  """

  @doc """
    Fetch the current token for the given `session_id`.

    Returns UUID.
  """
  defdelegate fetch_token(session_id),
    to: ApplicationRunner.Session.MetadataAgent,
    as: :fetch_token

  @doc """
    Start a Session GenServer for the given `session_id` (must be unique),
    with the given session_state.
    Make sure the environment Genserver is started for the given `env_id`,
    if the environment is not started, it is started with the given `env_state`.

    Returns {:ok, session_pid} | {:error, tuple()}
  """
  defdelegate start_session(session_state, env_state),
    to: ApplicationRunner.Session.DynamicSupervisor,
    as: :start_session

  @doc """
    Send an async call to the application,
    The call will run listeners for the given code `code` and `event`

    Returns :ok
  """
  defdelegate send_client_event(session_id, code, event),
    to: ApplicationRunner.Session.Manager,
    as: :send_client_event
end
