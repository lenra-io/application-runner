defmodule ApplicationRunner.Environments.Token do
  @moduledoc """
    The Environment Token is attached to an environment for the app to authenticate.
    Any data query must send this token, the data route then check the token stored.
  """

  alias ApplicationRunner.Environments

  alias ApplicationRunner.Guardian.AppGuardian

  alias ApplicationRunner.Environments.Supervisor

  def create_token(env_id) do
    with {:ok, token, _claims} <-
           AppGuardian.encode_and_sign(env_id, %{type: "env", env_id: env_id}) do
      {:ok, token}
    end
  end

  def fetch_token(env_id) do
    with agent <- Supervisor.fetch_module_pid!(env_id, Environments.Agent.Metadata) do
      Agent.get(agent, fn state -> state end)
    end
  end
end
