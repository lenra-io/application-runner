defmodule ApplicationRunner.Environment.MongoInstance do
  @moduledoc """
    This module provide the config option to start the `Mongo` genserver in the environment supervisor.
  """
  @env Application.compile_env!(:application_runner, :env)
  @mongo_url Application.compile_env!(:application_runner, :mongo_url)

  use SwarmNamed

  def config(env_id) do
    database_name = @env <> "_#{env_id}"

    [
      url: "#{@mongo_url}/#{database_name}",
      name: get_full_name(env_id)
    ]
  end
end

defimpl Jason.Encoder, for: BSON.ObjectId do
  def encode(val, _opts \\ []) do
    val
    |> BSON.ObjectId.encode!()
    |> Jason.encode!()
  end
end
