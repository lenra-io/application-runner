defmodule ApplicationRunner.Environment.MetadataAgent do
  @moduledoc """
    ApplicationRunner.Environment.MetadataAgent manages environment state
  """
  use Agent
  use SwarmNamed

  alias ApplicationRunner.Environment

  def start_link(%Environment.Metadata{} = env_metadata) do
    Agent.start_link(fn -> env_metadata end, name: get_full_name(env_metadata.env_id))
  end

  def fetch_token(env_id) do
    Agent.get(
      get_full_name(env_id),
      fn %Environment.Metadata{} = env_metadata ->
        env_metadata.token
      end
    )
  end
end
