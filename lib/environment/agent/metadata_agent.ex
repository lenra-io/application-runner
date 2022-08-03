defmodule ApplicationRunner.Environments.Agent.Metadata do
  @moduledoc """
    ApplicationRunner.Environments.Agent.Metadata manages environment state
  """
  use Agent

  alias ApplicationRunner.Environments
  alias ApplicationRunner.Environments.Token

  def start_link(opts) do
    env_supervisor_pid = Keyword.fetch!(opts, :env_supervisor_pid)
    state = Keyword.fetch!(opts, :env_state)
    env_id = Keyword.fetch!(opts, :env_id)
    function_name = Map.fetch!(state, :function_name)
    assigns = Map.fetch!(state, :assigns)

    case Token.create_token(env_id) do
      {:ok, token} ->
        env_state = %Environments.State{
          env_id: env_id,
          function_name: function_name,
          assigns: assigns,
          env_supervisor_pid: env_supervisor_pid,
          inactivity_timeout:
            Application.get_env(:application_runner, :env_inactivity_timeout, 1000 * 60 * 60),
          token: token
        }

        Agent.start_link(fn -> env_state end, name: {:via, :swarm, {:env_metadata, env_id}})

      {:error, error} ->
        raise error
    end
  end

  def handle_call(:fetch_env_supervisor_pid!, _from, env_state) do
    case Map.get(env_state, :env_supervisor_pid) do
      nil -> raise "No EnvSupervisor. This should not happen."
      res -> {:reply, res, env_state, env_state.inactivity_timeout}
    end
  end
end
