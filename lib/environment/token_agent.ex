defmodule ApplicationRunner.Environment.TokenAgent do
  @moduledoc """
    ApplicationRunner.Environment.TokenAgent manages token for session api request
  """
  use Agent

  alias ApplicationRunner.Environment.EnvironmentStateServices

  def start_link(opts) do
    with env_id when not is_nil(env_id) <- Keyword.get(opts, :env_id),
         {:ok, token} <- EnvironmentStateServices.create_token(env_id) do
      Agent.start_link(fn -> token end, name: {:global, env_id})
    else
      nil -> raise "EnvironmentState doesn't contain necessary information #{inspect(opts)}"
      err -> err
    end
  end
end
