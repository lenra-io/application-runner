defmodule ApplicationRunner.DocsControllerTest do
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

  describe "ApplicationRunner.DocsController.get_all" do
    test "should be protected with a token", %{conn: conn} do
      conn = get(conn, Routes.docs_path(conn, :get_all, @coll))

      assert %{"message" => _, "reason" => "unauthenticated"} = json_response(conn, 401)
    end

    test "Should return all docs", %{conn: conn, token: token} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> get(Routes.docs_path(conn, :get_all, @coll))

      assert %{"data" => [%{"foo" => "bar"}]} = json_response(conn, 200)
    end
  end

  describe "ApplicationRunner.DocsController.get" do
    test "should be protected with a token", %{conn: conn, doc_id: doc_id} do
      conn = get(conn, Routes.docs_path(conn, :get, @coll, doc_id))

      assert %{"message" => _, "reason" => "unauthenticated"} = json_response(conn, 401)
    end

    test "Should return the correct doc", %{conn: conn, token: token, doc_id: doc_id} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> get(Routes.docs_path(conn, :get, @coll, doc_id))

      assert %{"data" => %{"foo" => "bar"}} = json_response(conn, 200)
    end
  end

  describe "ApplicationRunner.DocsController.create" do
    test "should be protected with a token", %{conn: conn} do
      conn = post(conn, Routes.docs_path(conn, :create, @coll), %{"foo" => "bar"})

      assert %{"message" => _, "reason" => "unauthenticated"} = json_response(conn, 401)
    end

    test "Should create the new doc", %{conn: conn, token: token, mongo_pid: mongo_pid} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> post(Routes.docs_path(conn, :create, @coll), %{"foo" => "baz"})

      assert %{} = json_response(conn, 200)

      assert [%{"foo" => "bar"}, %{"foo" => "baz"}] =
               Mongo.find(mongo_pid, @coll, %{}) |> Enum.to_list()
    end
  end

  describe "ApplicationRunner.DocsController.update" do
    test "should be protected with a token", %{conn: conn, doc_id: doc_id} do
      conn = put(conn, Routes.docs_path(conn, :update, @coll, doc_id), %{"foo" => "bar"})

      assert %{"message" => _, "reason" => "unauthenticated"} = json_response(conn, 401)
    end

    test "Should update the doc", %{
      conn: conn,
      token: token,
      doc_id: doc_id,
      mongo_pid: mongo_pid
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> put(Routes.docs_path(conn, :update, @coll, doc_id), %{"foo" => "baz"})

      assert %{} = json_response(conn, 200)

      assert [%{"foo" => "baz"}] = Mongo.find(mongo_pid, @coll, %{}) |> Enum.to_list()
    end
  end

  describe "ApplicationRunner.DocsController.delete" do
    test "should be protected with a token", %{conn: conn, doc_id: doc_id} do
      conn = delete(conn, Routes.docs_path(conn, :delete, @coll, doc_id))

      assert %{"message" => _, "reason" => "unauthenticated"} = json_response(conn, 401)
    end

    test "Should delete the doc", %{
      conn: conn,
      token: token,
      doc_id: doc_id,
      mongo_pid: mongo_pid
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> delete(Routes.docs_path(conn, :delete, @coll, doc_id))

      assert %{} = json_response(conn, 200)

      assert [] = Mongo.find(mongo_pid, @coll, %{}) |> Enum.to_list()
    end
  end
end