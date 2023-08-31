defmodule ApplicationRunner.CollsControllerTest do
  use ApplicationRunner.ConnCase

  alias ApplicationRunner.Contract
  alias ApplicationRunner.Environment

  @coll "controller_test"

  setup ctx do
    Application.ensure_all_started(:postgrex)
    start_supervised(ApplicationRunner.Repo)

    {:ok, env} = ApplicationRunner.Repo.insert(Contract.Environment.new(%{}))

    token = ApplicationRunner.AppSocket.create_env_token(env.id) |> elem(1)

    env_metadata = %Environment.Metadata{
      env_id: env.id,
      function_name: "",
      token: token
    }

    {:ok, _} = start_supervised({Environment.MetadataAgent, env_metadata})
    {:ok, pid} = start_supervised({Mongo, Environment.MongoInstance.config(env.id)})

    start_supervised(
      {Task.Supervisor,
       name:
         {:via, :swarm,
          {ApplicationRunner.Environment.MongoInstance.TaskSupervisor,
           Environment.MongoInstance.get_name(env.id)}}}
    )

    Mongo.drop_collection(pid, @coll)

    doc_id =
      Mongo.insert_one!(pid, @coll, %{"foo" => "bar"})
      |> Map.get(:inserted_id)
      |> BSON.ObjectId.encode!()

    {:ok, Map.merge(ctx, %{mongo_pid: pid, token: token, doc_id: doc_id})}
  end

  describe "ApplicationRunner.CollsController.delete" do
    test "should be protected with a token", %{conn: conn} do
      conn = delete(conn, Routes.colls_path(conn, :delete, @coll))

      assert %{"message" => _, "reason" => "unauthenticated"} = json_response(conn, 401)
    end

    test "Should delete the coll", %{conn: conn, token: token} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> delete(Routes.colls_path(conn, :delete, @coll))

      assert %{} = json_response(conn, 200)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> get(Routes.docs_path(conn, :get_all, @coll))

      assert [] = json_response(conn, 200)
    end

    test "try delete unset coll", %{conn: conn, token: token} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> delete(Routes.colls_path(conn, :delete, "test"))

      assert %{
               "message" => "Could not access mongo. Please try again later.",
               "metadata" => %{"code" => 26, "message" => "ns not found"},
               "reason" => "mongo_error"
             } = json_response(conn, 500)
    end
  end
end
