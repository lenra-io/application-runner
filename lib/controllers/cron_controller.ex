defmodule ApplicationRunner.CronController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Crons

  def create(conn, %{"env_id" => env_id} = params) do
    {env_id_int, ""} = Integer.parse(env_id)

    with {:ok, cron} <-
           env_id_int
           |> Crons.create(params) do
      conn
      |> reply(cron)
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
