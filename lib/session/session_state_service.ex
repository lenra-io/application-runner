defmodule ApplicationRunner.Session.SessionStateServices do
  @moduledoc """
    Lenra.Sessionstate handle all operation for session state.
  """

  alias ApplicationRunner.{Guardian.AppGuardian, Session.TokenAgent, SessionSupervisor}

  def create_token(session_id, user_id, env_id) do
    with {:ok, token, _claims} <-
           AppGuardian.encode_and_sign(session_id, %{
             type: "session",
             user_id: user_id,
             env_id: env_id
           }) do
      {:ok, token}
    end
  end

  def fetch_token(session_id) do
    with agent <-
           SessionSupervisor.fetch_module_pid!(session_id, TokenAgent) do
      Agent.get(agent, fn state -> state end)
    end
  end
end
