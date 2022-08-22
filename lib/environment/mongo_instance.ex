defmodule ApplicationRunner.Environment.MongoInstance do
  @env Application.compile_env!(:application_runner, :env)
  @mongo_base_url Application.compile_env!(:application_runner, :mongo_base_url)

  def config(env_id) do
    database_name = @env <> "_#{env_id}"

    [
      url: "#{@mongo_base_url}/#{database_name}",
      name: get_full_name(env_id)
    ]
  end

  def get_name(env_id) do
    {__MODULE__, env_id}
  end

  def get_full_name(env_id) do
    {:via, :swarm, get_name(env_id)}
  end
end
