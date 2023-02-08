defmodule ApplicationRunner.Webhooks.WebhooksController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Webhooks.WebhookServices

  require Logger

  def create(conn, params) do
    Logger.debug(
      "#{__MODULE__} handle #{conn.method} on #{conn.request_path} with path_params #{conn.path_params} and body_params #{conn.body_params}"
    )

    with {:ok, webhook} <-
           Guardian.Plug.current_resource(conn)
           |> WebhookServices.app_create(params) do
      conn
      |> reply(webhook)
    end
  end

  def trigger(conn, %{"webhook_uuid" => uuid} = _params) do
    Logger.debug(
      "#{__MODULE__} handle #{conn.method} on #{conn.request_path} with path_params #{conn.path_params} and body_params #{conn.body_params}"
    )

    conn
    |> reply(WebhookServices.trigger(uuid, conn.body_params))
  end

  def trigger(_conn, params) do
    Logger.error(BusinessError.null_parameters_tuple(params))
    BusinessError.null_parameters_tuple(params)
  end
end
