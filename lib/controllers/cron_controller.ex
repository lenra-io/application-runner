defmodule ApplicationRunner.CronController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Environment.MetadataAgent
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Crons
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Guardian.AppGuardian

  def app_create(conn, params) do
    case AppGuardian.Plug.current_resource(conn) do
      nil ->
        BusinessError.invalid_token_tuple()

      {:ok, %{environment: env} = _resources} ->
        with %Environment.Metadata{} = metadata <- MetadataAgent.get_metadata(env.id),
             :ok <-
               Crons.create(env.id, metadata.function_name, params) do
          reply(conn, :ok)
        end
    end
  end

  def get(conn, %{"id" => cron_id} = _params) do
    with {:ok, cron} <-
           Crons.get(cron_id) do
      reply(conn, cron)
    end
  end

  def all(conn, %{"env_id" => env_id, "user_id" => user_id} = _params) do
    reply(conn, Crons.all(env_id, user_id))
  end

  def all(conn, %{"env_id" => env_id} = _params) do
    reply(conn, Crons.all(env_id))
  end

  def all(conn, _params) do
    case AppGuardian.Plug.current_resource(conn) do
      nil ->
        raise BusinessError.invalid_token()

      {:ok, %{environment: env} = _resources} ->
        reply(conn, Crons.all(env.id))
    end
  end

  def update(conn, %{"name" => name} = params) do
    with {:ok, cron} <- Crons.get_by_name(name),
         :ok <- Crons.update(cron, params) do
      reply(conn, :ok)
    end
  end

  def delete(conn, %{"name" => name} = _params) do
    with {:ok, cron} <- Crons.get_by_name(name),
         :ok <- Crons.delete(cron) do
      reply(conn, :ok)
    end
  end
end
