defmodule ApplicationRunner.CronController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Crons
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Environment.MetadataAgent
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Guardian.AppGuardian

  def create(conn, params) do
    with %{environment: env} <- AppGuardian.Plug.current_resource(conn),
         %Environment.Metadata{} = metadata <- MetadataAgent.get_metadata(env.id),
         {:ok, name} <-
           Crons.create(env.id, metadata.function_name, params) do
      reply(conn, name)
    else
      nil -> BusinessError.invalid_token_tuple()
      err -> err
    end
  end

  # def get(conn, %{"name" => cron_name} = _params) do
  #   with {:ok, cron} <-
  #          Crons.get_by_name(cron_name) do
  #     reply(conn, cron)
  #   end
  # end

  # def index(conn, %{"env_id" => env_id, "user_id" => user_id} = _params) do
  #   reply(conn, Crons.all(env_id, user_id))
  # end

  # def index(conn, %{"env_id" => env_id} = _params) do
  #   reply(conn, Crons.all(env_id))
  # end

  def index(conn, _params) do
    case AppGuardian.Plug.current_resource(conn) do
      nil ->
        raise BusinessError.invalid_token()

      %{environment: env} ->
        reply(conn, Crons.all(env.id))
    end
  end

  def update(conn, %{"name" => name} = params) do
    {:ok, loaded_name} = ApplicationRunner.Ecto.Reference.load(name)

    with {:ok, cron} <- Crons.get_by_name(loaded_name),
         :ok <- Crons.update(cron, params) do
      reply(conn, :ok)
    end
  end

  def delete(conn, %{"name" => name} = _params) do
    {:ok, loaded_name} = ApplicationRunner.Ecto.Reference.load(name)

    with :ok <- Crons.delete(loaded_name) do
      reply(conn, :ok)
    end
  end
end
