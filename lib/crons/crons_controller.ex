defmodule ApplicationRunner.Crons.CronsController do
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

  def get(conn, %{"user_id" => user_id}) do
    with {:ok, cron} <-
           Guardian.Plug.current_resource(conn)
           |> CronServices.get(user_id) do
      conn
      |> reply(cron)
    end
  end

  def get(conn, _params) do
    with {:ok, cron} <-
           Guardian.Plug.current_resource(conn)
           |> CronServices.get() do
      conn
      |> reply(cron)
    end
  end
end
