defmodule ApplicationRunner.Webhooks.WebhookTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.Environment
  alias ApplicationRunner.Environment.{Metadata, MetadataAgent}
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook
  alias ApplicationRunner.WebhookServices

  setup do
    {:ok, env} = Repo.insert(Environment.new())
    token = ApplicationRunner.AppChannel.do_create_env_token(env.id) |> elem(1)

    env_metadata = %Metadata{
      env_id: env.id,
      function_name: "test",
      token: token
    }

    {:ok, _} = start_supervised({MetadataAgent, env_metadata})

    {:ok, env_id: env.id}
  end

  test "Webhook get should work properly", %{env_id: env_id} do
    assert {:ok, webhook} =
             Webhook.new(env_id, %{"action" => "listener"})
             |> Repo.insert()

    bypass = Bypass.open()
    Bypass.stub(bypass, "POST", "/function/test", &handle_request(&1))

    WebhookServices.trigger(webhook.uuid, %{})
  end

  defp handle_request(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    body_decoded =
      if String.length(body) != 0 do
        Jason.decode!(body)
      else
        ""
      end

    case body_decoded do
      # Manifest no body
      "" ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"manifest" => @manifest}))

      # Listeners "action" in body
      %{"action" => _action} ->
        Plug.Conn.resp(conn, 200, "")

      # Widget data key
      %{"data" => data, "props" => props, "widget" => widget} ->
        {:ok, widget} = ApplicationRunnerAdapter.get_widget(%{}, widget, data, props)

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(widget)
        )
    end
  end
end
