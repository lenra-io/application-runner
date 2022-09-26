defmodule ApplicationRunner.Webhooks.WebhooksController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Webhooks.WebhookServices

  def create(conn, params) do
    with {:ok, webhook} <-
           Guardian.Plug.current_resource(conn)
           |> WebhookServices.app_create(params) do
      conn
      |> reply(webhook)
    end
  end

  def trigger(conn, params) do
    IO.inspect(params)
    IO.inspect(conn.body_params)
    IO.inspect(WebhookServices.trigger(params["webhook_uuid"], conn.body_params))

    conn
    |> reply(%{})
  end
end
