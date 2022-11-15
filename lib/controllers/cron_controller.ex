defmodule ApplicationRunner.CronController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Crons
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Guardian.AppGuardian

  def create(conn, %{"env_id" => env_id} = params) do
    case Integer.parse(env_id) do
      {env_id_int, ""} ->
        with {:ok, cron} <-
               env_id_int
               |> Crons.create(params) do
          conn
          |> reply(cron)
        end

      :error ->
        BusinessError.invalid_params_tuple()
    end
  end

  def app_create(conn, params) do
    case AppGuardian.Plug.current_resource(conn) do
      nil ->
        raise BusinessError.invalid_token()

      {:ok, %{environment: env} = _resources} ->
        with {:ok, cron} <-
               env.id
               |> Crons.create(params) do
          conn
          |> reply(cron)
        end
    end
  end

  def get(conn, %{"id" => cron_id} = _params) do
    with {:ok, cron} <-
           Crons.get(cron_id) do
      conn
      |> reply(cron)
    end
  end

  def all(conn, %{"env_id" => env_id, "user_id" => user_id} = _params) do
    conn
    |> reply(Crons.all(env_id, user_id))
  end

  def all(conn, %{"env_id" => env_id} = _params) do
    conn
    |> reply(Crons.all(env_id))
  end

  def update(conn, %{"id" => cron_id} = params) do
    with {:ok, cron} <- Crons.get(cron_id),
         {:ok, updated_cron} <- Crons.update(cron, params) do
      conn
      |> reply(updated_cron)
    end
  end
end
