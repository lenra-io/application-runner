defmodule ApplicationRunner.Webhooks.ControllerTest do
  use ApplicationRunner.ConnCase

  alias ApplicationRunner.Contract
  alias ApplicationRunner.Environment

  @coll "controller_test"

  setup ctx do
    {:ok, ctx}
  end

  defp setup_session_token do
    Application.ensure_all_started(:postgrex)
    {:ok, _} = start_supervised(ApplicationRunner.FakeEndpoint)
    start_supervised(ApplicationRunner.Repo)

    {:ok, env} = ApplicationRunner.Repo.insert(Contract.Environment.new(%{}))

    user =
      %{email: "test@test.te"}
      |> Contract.User.new()
      |> ApplicationRunner.Repo.insert!()

    token =
      ApplicationRunner.AppChannel.do_create_session_token(env.id, Ecto.UUID.generate(), user.id)
      |> elem(1)

    env_metadata = %Environment.Metadata{
      env_id: env.id,
      function_name: "",
      token: token
    }

    {:ok, _} = start_supervised({Environment.MetadataAgent, env_metadata})
    {:ok, pid} = start_supervised({Mongo, Environment.MongoInstance.config(env.id)})

    Mongo.drop_collection(pid, @coll)

    doc_id =
      Mongo.insert_one!(pid, @coll, %{"foo" => "bar"})
      |> Map.get(:inserted_id)
      |> BSON.ObjectId.encode!()

    {:ok, %{mongo_pid: pid, token: token, doc_id: doc_id, env_id: env.id}}
  end

  defp setup_env_token do
    Application.ensure_all_started(:postgrex)
    {:ok, _} = start_supervised(ApplicationRunner.FakeEndpoint)
    start_supervised(ApplicationRunner.Repo)

    {:ok, env} = ApplicationRunner.Repo.insert(Contract.Environment.new(%{}))

    token = ApplicationRunner.AppChannel.do_create_env_token(env.id) |> elem(1)

    env_metadata = %Environment.Metadata{
      env_id: env.id,
      function_name: "",
      token: token
    }

    {:ok, _} = start_supervised({Environment.MetadataAgent, env_metadata})
    {:ok, pid} = start_supervised({Mongo, Environment.MongoInstance.config(env.id)})

    Mongo.drop_collection(pid, @coll)

    doc_id =
      Mongo.insert_one!(pid, @coll, %{"foo" => "bar"})
      |> Map.get(:inserted_id)
      |> BSON.ObjectId.encode!()

    {:ok, %{mongo_pid: pid, token: token, doc_id: doc_id, env_id: env.id}}
  end

  test "Create webhook in env should work properly", %{conn: conn} do
    {:ok, %{token: token}} = setup_env_token()

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> post(Routes.webhook_path(conn, :create), %{
        "action" => "test"
      })

    response = json_response(conn, 200)

    assert %{"action" => "test", "props" => nil} = response

    assert [webhook] = ApplicationRunner.Webhooks.WebhookServices.get(response["environment_id"])

    assert webhook.action == "test"
  end

  test "Create webhook in session should work properly", %{
    conn: conn
  } do
    {:ok, %{token: token}} = setup_session_token()

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> post(Routes.webhook_path(conn, :create), %{
        "action" => "test"
      })

    response = json_response(conn, 400)

    assert %{"action" => "test", "props" => nil} = response

    assert [webhook] =
             ApplicationRunner.Webhooks.WebhookServices.get(response["data"]["environment_id"])

    assert webhook.action == "test"
  end
end
