defmodule ApplicationRunner.Environment.TokenAgent do
  @moduledoc """
    Lenra.SessionAgent manage token for session api request
  """
  use Agent

  alias ApplicationRunner.Environment.EnvironmentStateServices

  def start_link(%{env_id: env_id}) do
    with {:ok, token} <- EnvironmentStateServices.create_token(env_id) do
      Agent.start_link(fn -> token end, name: {:global, env_id})
    end
  end

  def start_link(state) do
    raise "EnvironmentState doesn't contains necessary information #{inspect(state)}"
  end
end
