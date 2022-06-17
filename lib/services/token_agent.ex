defmodule ApplicationRunner.Session.TokenAgent do
  @moduledoc """
    Lenra.SessionAgent manage token for session api request
  """
  use Agent

  alias ApplicationRunner.Session.SessionStateServices

  def start_link(%{env_id: env_id, session_id: session_id, user_id: user_id}) do
    with {:ok, token} <- SessionStateServices.create_token(session_id, user_id, env_id) do
      Agent.start_link(fn -> token end, name: {:global, session_id})
    end
  end

  def start_liink(_) do
    raise "EnvironmentState doesn't contains necessary information"
  end
end
