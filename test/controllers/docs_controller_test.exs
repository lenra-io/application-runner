defmodule ApplicationRunner.DocsControllerTest do
  use ApplicationRunner.ConnCase

  alias ApplicationRunner.Environment.MongoInstance

  @env_id 42
  @coll "controller_test"

  setup ctx do
    {:ok, pid} = start_supervised({Mongo, MongoInstance.config(@env_id)})
    Mongo.drop_collection(pid, @coll)
    Mongo.insert_one!(pid, @coll, %{"foo" => "bar"})
    {:ok, Map.merge(ctx, %{mongo_pid: pid})}
  end

  describe "ApplicationRunner.DocsController.get_all" do
    test "should be protected with a token", %{conn: conn} do
      conn = get(conn, Routes.docs_path(conn, :get_all, @coll))

      assert %{"message" => _, "reason" => "unauthenticated"} = json_response(conn, 401)
    end

    test "Should return the correct data", %{conn: conn} do
      {:ok, token} = ApplicationRunner.AppChannel.do_create_env_token(@env_id)

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
        |> get(Routes.docs_path(conn, :get_all, @coll))

      assert %{"data" => [%{"foo" => "bar"}]} = json_response(conn, 200)
    end
  end
end
