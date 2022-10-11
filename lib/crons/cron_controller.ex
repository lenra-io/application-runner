defmodule ApplicationRunner.Crons.CronController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Crons.CronServices

  def create(conn, params) do
    with {:ok, cron} <-
           Guardian.Plug.current_resource(conn)
           |> CronServices.create(params) do
      conn
      |> reply(cron)
    end
  end

  def get(conn, %{"id" => cron_id} = _params) do
    with {:ok, cron} <-
           CronServices.get(cron_id) do
      conn
      |> reply(cron)
    end
  end

  def get_all(conn, %{"user_id" => user_id}) do
    with {:ok, cron} <-
           Guardian.Plug.current_resource(conn)
           |> CronServices.get_all(user_id) do
      conn
      |> reply(cron)
    end
  end

  def get_all(conn, _params) do
    with {:ok, cron} <-
           Guardian.Plug.current_resource(conn)
           |> CronServices.get_all() do
      conn
      |> reply(cron)
    end
  end

  def update(conn, %{"id" => cron_id} = params) do
    with {:ok, cron} <- CronServices.get(cron_id),
         {:ok, updated_cron} <- CronServices.update(cron, params) do
      conn
      |> reply(updated_cron)
    end
  end
end
