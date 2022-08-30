defmodule ApplicationRunner.Environment.Supervisor do
  @moduledoc """
    This module handles the children module of an AppManager.
  """
  use Supervisor
  use SwarmNamed

  alias ApplicationRunner.Environment

  alias ApplicationRunner.Environment.{
    ChangeStream,
    MongoInstance,
    QueryDynSup,
    WidgetDynSup
  }

  alias ApplicationRunner.Session

  def start_link(%Environment.Metadata{} = env_metadata) do
    env_id = Map.fetch!(env_metadata, :env_id)

    Supervisor.start_link(__MODULE__, env_metadata, name: get_full_name(env_id))
  end

  @impl true
  def init(%Environment.Metadata{} = env_metadata) do
    children = [
      # TODO: add module once they done !
      {ApplicationRunner.Environment.MetadataAgent, env_metadata},
      {ApplicationRunner.Environment.ManifestHandler, env_metadata},
      # ApplicationRunner.EventHandler,
      {Mongo, MongoInstance.config(env_metadata.env_id)},
      {ChangeStream, env_id: env_metadata.env_id},
      # MongoSessionDynamicSup
      # MongoTransaDynSup
      # {ApplicationRunner.Environment.Task.OnEnvStart, opts}
      # {ApplicationRunner.Environment.ManifestHandler, opts}
      # ApplicationRunner.ListenersCache
      {QueryDynSup, env_id: env_metadata.env_id},
      {WidgetDynSup, env_id: env_metadata.env_id},
      {Session.DynamicSupervisor, env_metadata}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
