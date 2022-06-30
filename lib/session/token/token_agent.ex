defmodule ApplicationRunner.Session.Token.Agent do
  @moduledoc """
    ApplicationRunner.Session.TokenAgent manages token for session api request
  """
  use Agent

  alias ApplicationRunner.Session.Token

  def start_link(opts) do
    with env_id when not is_nil(env_id) <- Keyword.get(opts, :env_id),
         session_id when not is_nil(session_id) <- Keyword.get(opts, :session_id),
         session_state when not is_nil(session_state) <- Keyword.get(opts, :session_state),
         user_id when not is_nil(user_id) <- Map.get(session_state, :user_id),
         {:ok, token} <- Token.create_token(session_id, user_id, env_id) do
      Agent.start_link(fn -> token end, name: {:global, session_id})
    else
      nil -> raise "SessionState doesn't contain necessary information #{inspect(opts)}"
      err -> err
    end
  end
end
