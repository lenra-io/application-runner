defmodule ApplicationRunner.Environment.MongoInstance do
  @moduledoc """
    This module provide the config option to start the `Mongo` genserver in the environment supervisor.
  """
  @env Application.compile_env!(:application_runner, :env)

  use SwarmNamed

  def config(env_id) do
    database_name = @env <> "_#{env_id}"
    mongo_url = Application.fetch_env!(:application_runner, :mongo_url)

    [
      url: "#{mongo_url}/#{database_name}",
      name: get_full_name(env_id),
      pool_size: 10
    ]
  end
end

defimpl Jason.Encoder, for: BSON.ObjectId do
  def encode(val, _opts \\ []) do
    val
    |> BSON.ObjectId.encode!()
    |> (fn str -> "ObjectId(#{str})" end).()
    |> Jason.encode!()
  end
end
