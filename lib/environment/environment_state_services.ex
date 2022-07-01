defmodule ApplicationRunner.Environment.Token do
  @moduledoc """
    Lenra.Sessionstate handle all operation for session state.
  """

  alias ApplicationRunner.Guardian.AppGuardian

  alias ApplicationRunner.Environment.{
    Token,
    Supervisor
  }

  def create_token(env_id) do
    with {:ok, token, _claims} <-
           AppGuardian.encode_and_sign(env_id, %{type: "env", env_id: env_id}) do
      {:ok, token}
    end
  end

  def fetch_token(env_id) do
    with agent <- Supervisor.fetch_module_pid!(env_id, Token.Agent) do
      Agent.get(agent, fn state -> state end)
    end
  end
end
