defmodule ApplicationRunner.Environment.Supervisor do
  @moduledoc """
    This module handles the children module of an AppManager.
  """
  use Supervisor
  use SwarmNamed

  alias ApplicationRunner.Environment
  alias ApplicationRunner.Session

  def start_link(%Environment.Metadata{} = env_metadata) do
    env_id = Map.fetch!(env_metadata, :env_id)

    Supervisor.start_link(__MODULE__, env_metadata, name: get_full_name(env_id))
  end

  @impl true
  def init(%Environment.Metadata{} = em) do
    children = [
      # TODO: add module once they done !
      {Environment.MetadataAgent, em},
      {Environment.ManifestHandler, env_id: em.env_id, function_name: em.function_name},
      {ApplicationRunner.EventHandler, mode: :env, id: em.env_id},
      {Mongo, Environment.MongoInstance.config(em.env_id)},
      {Environment.Events.OnEnvStart, env_id: em.env_id},
      {Environment.ChangeStream, env_id: em.env_id},
      # MongoSessionDynamicSup
      {Environment.QueryDynSup, env_id: em.env_id},
      {Environment.ViewDynSup, env_id: em.env_id},
      {Session.DynamicSupervisor, env_id: em.env_id}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
