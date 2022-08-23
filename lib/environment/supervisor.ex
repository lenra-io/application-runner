defmodule ApplicationRunner.Environment.Supervisor do
  @moduledoc """
    This module handles the children module of an AppManager.
  """
  use Supervisor
  use SwarmNamed

  alias ApplicationRunner.Environment.MongoInstance
  alias ApplicationRunner.Environment

  def start_link(%Environment.Metadata{} = env_metadata) do
    env_id = Map.fetch!(env_metadata, :env_id)

    Supervisor.start_link(__MODULE__, env_metadata, name: get_full_name(env_id))
  end

  @impl true
  def init(%Environment.Metadata{} = env_metadata) do
    children = [
      # TODO: add module once they done !
      {ApplicationRunner.Environment.MetadataAgent, env_metadata},
      ApplicationRunner.EventHandler,
      {Mongo, MongoInstance.config(env_metadata.env_id)}
      # ChangeStream
      # MongoSessionDynamicSup
      # MongoTransaDynSup
      # {ApplicationRunner.Environment.Task.OnEnvStart, opts}
      # {ApplicationRunner.Environment.ManifestHandler, opts}
      # ApplicationRunner.ListenersCache
      # QueryDynSup
      # WidgetDynSup
      # Session.Managers
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
