defmodule ApplicationRunner.Webhooks.ControllerTest do
  use ApplicationRunner.ConnCase

  alias ApplicationRunner.Contract
  alias ApplicationRunner.Environment

  @coll "controller_test"

  setup ctx do
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

    {:ok, Map.merge(ctx, %{mongo_pid: pid, token: token, doc_id: doc_id})}
  end

  test "aaaaaaaaa", %{conn: conn, token: token} do
    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> post(Routes.webhook_path(conn, :create), %{
        "action" => "test"
      })

    assert %{"action" => "test", "props" => nil} = json_response(conn, 200)
  end
end
