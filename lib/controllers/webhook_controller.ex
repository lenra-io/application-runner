defmodule ApplicationRunner.WebhookController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Webhooks.WebhookServices

  def create(conn, params) do
    with {:ok, webhook} <-
           WebhookServices.app_create(Guardian.Plug.current_resource(conn), params) do
      conn
      |> assign_data(webhook)
      |> reply
    end
  end

  def index(_conn, _params) do
  end

  def trigger(_conn, _params) do
  end
end
