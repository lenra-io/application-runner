defmodule ApplicationRunner.Session.Agent.Metadata do
  @moduledoc """
    ApplicationRunner.Session.TokenAgent manages token for session api request
  """
  use Agent

  alias ApplicationRunner.Session

  def(start_link(opts)) do
    with env_id when not is_nil(env_id) <- Keyword.get(opts, :env_id),
         session_id when not is_nil(session_id) <- Keyword.get(opts, :session_id),
         session_state when not is_nil(session_state) <- Keyword.get(opts, :session_state),
         session_supervisor_pid when not is_nil(session_supervisor_pid) <-
           Keyword.get(opts, :session_supervisor_pid),
         assigns when not is_nil(assigns) <- Map.get(session_state, :assigns),
         user_id when not is_nil(user_id) <- Map.get(session_state, :user_id),
         function_name when not is_nil(function_name) <- Map.get(session_state, :function_name),
         {:ok, token} <- Session.Agent.create_token(session_id, user_id, env_id) do
      env_state = %Session.State{
        env_id: env_id,
        session_id: session_id,
        function_name: function_name,
        user_id: user_id,
        assigns: assigns,
        session_supervisor_pid: session_supervisor_pid,
        inactivity_timeout:
          Application.get_env(:application_runner, :env_inactivity_timeout, 1000 * 60 * 60),
        token: token
      }

      Agent.start_link(fn -> env_state end,
        name: {:via, :swarm, {:session_metadata, session_id}}
      )
    else
      error -> raise error
    end
  end

  def handle_call(:fetch_session_supervisor_pid!, _from, env_state) do
    case Map.get(env_state, :session_supervisor_pid) do
      nil -> raise "No SessionSupervisor. This should not happen."
      res -> {:reply, res, env_state, env_state.inactivity_timeout}
    end
  end
end
