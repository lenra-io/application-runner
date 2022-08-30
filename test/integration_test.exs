defmodule ApplicationRunner.IntegrationTest do
  use ExUnit.Case, async: false

  alias ApplicationRunner.{AppChannel, Environment, Session}

  @user_id 1
  @env_id 42
  @session_id 1337
  @function_name Ecto.UUID.generate()
  @url "/function/#{@function_name}"

  @coll "test_integration"
  @query %{"foo" => "bar"}

  @manifest %{"rootWidget" => "main"}

  @env_metadata %Environment.Metadata{
    env_id: @env_id,
    function_name: @function_name,
    token: "abc"
  }
  @session_metadata %Session.Metadata{
    env_id: @env_id,
    user_id: @user_id,
    session_id: @session_id,
    function_name: @function_name,
    token: "abcd"
  }

  def widget("main", _) do
    %{"type" => "widget", "name" => "echo", "query" => @query, "coll" => @coll}
  end

  def widget("echo", data) do
    %{"type" => "text", "value" => Jason.encode!(data)}
  end

  setup do
    bypass = Bypass.open(port: 1234)

    Bypass.stub(bypass, "POST", @url, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      case Jason.decode(body) do
        {:ok, json} ->
          name = Map.get(json, "widget")
          data = Map.get(json, "data")

          Plug.Conn.resp(
            conn,
            200,
            Jason.encode!(%{widget: widget(name, data)})
          )

        {:error, _} ->
          Plug.Conn.resp(conn, 200, Jason.encode!(%{manifest: @manifest}))
      end
    end)

    {:ok, %{bypass: bypass}}
  end

  # test "Check that all dependancies are started and correctly named" do
  #   assert {:ok, _pid} = Session.start_session(@session_metadata, @env_metadata)

  #   assert :undefined != Swarm.whereis_name(Environment.Supervisor.get_name(@env_id))
  #   assert :undefined != Swarm.whereis_name(Environment.MetadataAgent.get_name(@env_id))
  #   assert :undefined != Swarm.whereis_name(Environment.MongoInstance.get_name(@env_id))
  #   assert :undefined != Swarm.whereis_name(Environment.ChangeStream.get_name(@env_id))
  #   assert :undefined != Swarm.whereis_name(Environment.QueryDynSup.get_name(@env_id))
  #   assert :undefined != Swarm.whereis_name(Environment.WidgetDynSup.get_name(@env_id))
  #   assert :undefined != Swarm.whereis_name(Session.DynamicSupervisor.get_name(@env_id))

  #   assert :undefined != Swarm.whereis_name(Session.MetadataAgent.get_name(@session_id))
  #   assert :undefined != Swarm.whereis_name(Session.ChangeEventManager.get_name(@session_id))

  #   on_exit(fn ->
  #     Session.stop_session(@env_id, @session_id)
  #     :timer.sleep(1000)
  #   end)
  # end

  test "Integration test, check that the UI change when the mongo db coll change" do
    # Self must join AppChannel group to receive new UI
    Swarm.register_name(AppChannel.get_name(@session_id), self())
    Swarm.join(AppChannel.get_group(@session_id), self())
    # Start env
    Environment.DynamicSupervisor.ensure_env_started(@env_metadata)
    # Reset and setup mongo coll
    mongo_name = Environment.MongoInstance.get_full_name(@env_id)
    Mongo.drop_collection(mongo_name, @coll)
    Mongo.insert_one!(mongo_name, @coll, %{"foo" => "bar"})

    # Start the session and start one widget
    Session.start_session(@session_metadata, @env_metadata)

    # query = %{"foo" => "bar"}

    # widget_uid = %Environment.WidgetUid{
    #   name: "all",
    #   coll: coll,
    #   query: Jason.encode!(query),
    #   props: %{}
    # }

    # Environment.WidgetDynSup.ensure_child_started(
    #   @env_id,
    #   @session_id,
    #   @function_name,
    #   widget_uid
    # )

    # Get the actual data and compare
    data = Mongo.find(mongo_name, @coll, @query) |> Enum.to_list()
    assert Enum.count(data) == 1
    encoded_data = Jason.encode!(data)

    assert_receive {:send, :ui, %{"root" => %{"type" => "text", "value" => ^encoded_data}}}

    # Add one more data, get it and compare
    %{inserted_id: data_id} = Mongo.insert_one!(mongo_name, @coll, %{"foo" => "bar"})
    data = Mongo.find(mongo_name, @coll, @query) |> Enum.to_list()
    assert Enum.count(data) == 2
    encoded_data = Jason.encode!(data)
    # Wait for the widget to receive the new data
    # TODO : Remove this and wait for the ui_builder to receive the UI

    assert_receive {
      :send,
      :patches,
      [
        %{
          "value" => ^encoded_data,
          "op" => "replace",
          "path" => "/root/value"
        }
      ]
    }

    # Update the latest data and compare
    Mongo.update_one(mongo_name, @coll, %{"_id" => data_id}, %{"$set" => %{"foo" => "baz"}})
    data = Mongo.find(mongo_name, @coll, @query) |> Enum.to_list()
    assert Enum.count(data) == 1
    encoded_data = Jason.encode!(data)

    assert_receive {:send, :patches,
                    [
                      %{
                        "value" => ^encoded_data,
                        "op" => "replace",
                        "path" => "/root/value"
                      }
                    ]}

    on_exit(fn ->
      Session.stop_session(@env_id, @session_id)
      Swarm.unregister_name(Session.Supervisor.get_name(@session_id))
    end)
  end
end
