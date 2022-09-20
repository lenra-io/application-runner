defmodule ApplicationRunner.Webhooks.WebhookTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.{Environment, User}
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

    bypass = Bypass.open(port: 1234)

    {:ok, %{env_id: env.id, bypass: bypass}}
  end

  defp handle_request(conn, callback) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    body_decoded =
      if String.length(body) != 0 do
        Jason.decode!(body)
      else
        ""
      end

    callback.(body_decoded)

    case body_decoded do
      # Listeners "action" in body
      %{"action" => _action} ->
        Plug.Conn.resp(conn, 200, "")
    end
  end

  test "Webhook should properly trigger listener", %{env_id: env_id, bypass: bypass} do
    assert {:ok, webhook} =
             Webhook.new(env_id, %{"action" => "listener", "props" => %{"propKey" => "propValue"}})
             |> Repo.insert()

    Bypass.stub(
      bypass,
      "POST",
      "/function/test",
      &handle_request(&1, fn body ->
        assert body["props"] == %{"propKey" => "propValue"}
        assert body["action"] == "listener"
        assert body["event"] == %{"eventPropKey" => "eventPropValue"}
      end)
    )

    assert :ok == WebhookServices.trigger(webhook.uuid, %{"eventPropKey" => "eventPropValue"})
  end

  test "Trigger not existing webhook should return an error", %{env_id: _env_id, bypass: _bypass} do
    assert {:error, %LenraCommon.Errors.TechnicalError{reason: :error_404}} =
             WebhookServices.trigger(Ecto.UUID.generate(), %{})
  end

  test "User specific Webhook should properly trigger listener", %{env_id: env_id, bypass: bypass} do
    user =
      %{email: "test@test.te"}
      |> User.new()
      |> Repo.insert!()

    assert {:ok, webhook} =
             Webhook.new(env_id, %{
               "user_id" => user.id,
               "action" => "listener",
               "props" => %{"propKey" => "propValue"}
             })
             |> Repo.insert()

    Bypass.stub(
      bypass,
      "POST",
      "/function/test",
      &handle_request(&1, fn body ->
        assert body["props"] == %{"propKey" => "propValue"}
        assert body["action"] == "listener"
        assert body["event"] == %{"eventPropKey" => "eventPropValue"}
      end)
    )

    assert :ok == WebhookServices.trigger(webhook.uuid, %{"eventPropKey" => "eventPropValue"})
  end
end
