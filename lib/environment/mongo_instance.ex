defmodule ApplicationRunner.Environment.MongoInstance do
  @moduledoc """
    This module provide the config option to start the `Mongo` genserver in the environment supervisor.
  """
  @env Application.compile_env!(:application_runner, :env)

  require Logger

  use SwarmNamed

  def config(env_id) do
    database_name = @env <> "_#{env_id}"

    mongo_config = Application.fetch_env!(:application_runner, :mongo)

    case Integer.parse(mongo_config[:port]) do
      {port, _} ->
        [
          hostname: mongo_config[:hostname],
          port: port,
          database: database_name,
          username: mongo_config[:username],
          password: mongo_config[:password],
          ssl: mongo_config[:ssl],
          name: get_full_name(env_id),
          auth_source: mongo_config[:auth_source],
          pool_size: 10
        ]

      :error ->
        error = "Failed to parse Mongo port: " <> mongo_config[:port]
        Logger.emergency(error)
        raise error
    end
  end
end

defimpl Jason.Encoder, for: BSON.ObjectId do
  def encode(val, _opts \\ []) do
    val
    |> BSON.ObjectId.encode!()
    |> to_object_id_str()
    |> Jason.encode!()
  end

  defp to_object_id_str(str) do
    "ObjectId(#{str})"
  end
end
