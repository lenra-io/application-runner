defmodule ApplicationRunner.NotificationsController do
  use ApplicationRunner, :controller

  def notify(conn, params) do
    conn
    |> reply(:ok)
  end
end
