# defmodule ApplicationRunner.Webhooks.ControllerTest do
#   use ApplicationRunner.ConnCase

#   alias ApplicationRunner.Contract
#   alias ApplicationRunner.Environment
#   alias ApplicationRunner.MongoStorage.MongoUserLink
#   alias ApplicationRunner.Webhooks.WebhookServices

#   @coll "controller_test"

#   setup ctx do
#     Application.ensure_all_started(:postgrex)
#     {:ok, _} = start_supervised(ApplicationRunner.FakeEndpoint)
#     start_supervised(ApplicationRunner.Repo)

#     {:ok, ctx}
#   end

#   defp setup_session_token do
#     {:ok, env} = ApplicationRunner.Repo.insert(Contract.Environment.new(%{}))

#     user =
#       %{email: "test@test.te"}
#       |> Contract.User.new()
#       |> ApplicationRunner.Repo.insert!()

#     MongoUserLink.new(%{
#       "user_id" => user.id,
#       "environment_id" => env.id
#     })
#     |> ApplicationRunner.Repo.insert!()

#     session_uuid = Ecto.UUID.generate()

#     token =
#       ApplicationRunner.AppChannel.do_create_session_token(env.id, session_uuid, user.id)
#       |> elem(1)

#     session_metadata = %ApplicationRunner.Session.Metadata{
#       env_id: env.id,
#       session_id: session_uuid,
#       user_id: user.id,
#       function_name: "test",
#       token: token,
#       context: %{}
#     }

#     {:ok, _} = start_supervised({ApplicationRunner.Session.MetadataAgent, session_metadata})
#     {:ok, pid} = start_supervised({Mongo, Environment.MongoInstance.config(env.id)})

#     Mongo.drop_collection(pid, @coll)

#     doc_id =
#       Mongo.insert_one!(pid, @coll, %{"foo" => "bar"})
#       |> Map.get(:inserted_id)
#       |> BSON.ObjectId.encode!()

#     {:ok, %{mongo_pid: pid, token: token, doc_id: doc_id, env_id: env.id}}
#   end

#   defp setup_env_token do
#     {:ok, env} = ApplicationRunner.Repo.insert(Contract.Environment.new(%{}))

#     token = ApplicationRunner.AppChannel.do_create_env_token(env.id) |> elem(1)

#     env_metadata = %Environment.Metadata{
#       env_id: env.id,
#       function_name: "test",
#       token: token
#     }

#     {:ok, _} = start_supervised({Environment.MetadataAgent, env_metadata})
#     {:ok, pid} = start_supervised({Mongo, Environment.MongoInstance.config(env.id)})

#     Mongo.drop_collection(pid, @coll)

#     doc_id =
#       Mongo.insert_one!(pid, @coll, %{"foo" => "bar"})
#       |> Map.get(:inserted_id)
#       |> BSON.ObjectId.encode!()

#     {:ok, %{mongo_pid: pid, token: token, doc_id: doc_id, env_id: env.id}}
#   end

#   test "Create webhook in env should work properly", %{conn: conn} do
#     {:ok, %{token: token}} = setup_env_token()

#     conn =
#       conn
#       |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
#       |> post(Routes.webhooks_path(conn, :create), %{
#         "action" => "test"
#       })

#     response = json_response(conn, 200)

#     assert %{"action" => "test", "props" => nil} = response

#     assert [webhook] = WebhookServices.get(response["environment_id"])

#     assert webhook.action == "test"
#   end

#   test "Create webhook in session should work properly",
#        %{
#          conn: conn
#        } do
#     {:ok, %{token: token}} = setup_session_token()

#     conn =
#       conn
#       |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
#       |> post(Routes.webhooks_path(conn, :create), %{
#         "action" => "test"
#       })

#     response = json_response(conn, 200)

#     assert %{"action" => "test", "props" => nil} = response

#     assert [webhook] = WebhookServices.get(response["environment_id"])

#     assert webhook.action == "test"
#   end

#   defp handle_request(conn, callback) do
#     {:ok, body, conn} = Plug.Conn.read_body(conn)

#     body_decoded =
#       if String.length(body) != 0 do
#         Jason.decode!(body)
#       else
#         ""
#       end

#     callback.(body_decoded)

#     case body_decoded do
#       # Listeners "action" in body
#       %{"action" => _action} ->
#         Plug.Conn.resp(conn, 200, "")
#     end
#   end

#   test "Trigger webhook in env should work properly", %{conn: conn} do
#     {:ok, %{token: token}} = setup_env_token()

#     conn =
#       conn
#       |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
#       |> post(Routes.webhooks_path(conn, :create), %{
#         "action" => "test"
#       })

#     response = json_response(conn, 200)

#     bypass = Bypass.open(port: 1234)

#     Bypass.stub(
#       bypass,
#       "POST",
#       "/function/test",
#       &handle_request(&1, fn body ->
#         assert body["props"] == nil
#         assert body["action"] == "test"
#         assert body["event"] == %{"payloadData" => "Value"}
#       end)
#     )

#     conn =
#       conn
#       |> post(Routes.webhooks_path(conn, :trigger, response["uuid"]), %{
#         "payloadData" => "Value"
#       })

#     assert _res = json_response(conn, 200)
#   end
# end