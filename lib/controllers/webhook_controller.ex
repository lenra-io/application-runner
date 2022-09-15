defmodule ApplicationRunner.WebhookController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.WebhookServices

  def create(conn, %{"environment_id" => env_id} = params) do
    with {:ok, webhook} <- WebhookServices.create(env_id, params) do
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
