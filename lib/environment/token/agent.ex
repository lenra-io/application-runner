defmodule ApplicationRunner.Environments.Token.Agent do
  @moduledoc """
    ApplicationRunner.Environments.Token.Agent manages token for session api request
  """
  use Agent

  alias ApplicationRunner.Environments.Token

  def start_link(opts) do
    with env_id when not is_nil(env_id) <- Keyword.get(opts, :env_id),
         {:ok, token} <- Token.create_token(env_id) do
      Agent.start_link(fn -> token end, name: {:global, env_id})
    else
      nil -> raise "Environments.State doesn't contain necessary information #{inspect(opts)}"
      err -> err
    end
  end
end
