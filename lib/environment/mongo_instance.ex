defmodule ApplicationRunner.Environment.MongoInstance do
  @moduledoc """
    This module provide the config option to start the `Mongo` genserver in the environment supervisor.
  """
  @env Application.compile_env!(:application_runner, :env)
  @mongo_base_url Application.compile_env!(:application_runner, :mongo_base_url)

  use SwarmNamed

  def config(env_id) do
    database_name = @env <> "_#{env_id}"

    [
      url: "#{@mongo_base_url}/#{database_name}",
      name: get_full_name(env_id)
    ]
  end
end
