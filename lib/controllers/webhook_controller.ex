defmodule ApplicationRunner.WebhookController do
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

  def index(_conn, _params) do
  end

  def trigger(_conn, _params) do
  end
end
