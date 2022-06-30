defmodule ApplicationRunner.Session.Token do
  @moduledoc """
    Lenra.Sessionstate handle all operation for session state.
  """

  alias ApplicationRunner.Guardian.AppGuardian

  alias ApplicationRunner.Session.{
    Supervisor,
    Token
  }

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
           Supervisor.fetch_module_pid!(session_id, Token.Agent) do
      Agent.get(agent, fn state -> state end)
    end
  end
end
