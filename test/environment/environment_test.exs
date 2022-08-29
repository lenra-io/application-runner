defmodule ApplicationRunner.EnvironmentTest do
  use ExUnit.Case, async: false

  alias ApplicationRunner.{Environment, Session}

  @user_id 1
  @env_id 42
  @session_id 1337
  @function_name Ecto.UUID.generate()
  @url "/function/#{@function_name}"

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

  setup do
    bypass = Bypass.open(port: 1234)

    Bypass.stub(bypass, "POST", @url, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      case Jason.decode(body) do
        {:ok, json} ->
          data = Map.get(json, "data")

          Plug.Conn.resp(
            conn,
            200,
            Jason.encode!(%{widget: %{"type" => "text", "value" => Jason.encode!(data)}})
          )

        {:error, _} ->
          Plug.Conn.resp(conn, 200, Jason.encode!(%{manifest: %{"rootWidget" => "main"}}))
      end
    end)

    {:ok, %{bypass: bypass}}
  end

  test "Check that all dependancies are started and correctly named" do
    assert {:ok, pid} = Session.start_session(@session_metadata, @env_metadata)

    assert :undefined != Swarm.whereis_name(Environment.Supervisor.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.MetadataAgent.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.MongoInstance.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.ChangeStream.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.QueryDynSup.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.WidgetDynSup.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Session.DynamicSupervisor.get_name(@env_id))

    assert :undefined != Swarm.whereis_name(Session.MetadataAgent.get_name(@session_id))
    assert :undefined != Swarm.whereis_name(Session.ChangeEventManager.get_name(@session_id))

    on_exit(fn ->
      Session.stop_session(@env_id, @session_id)
      Swarm.unregister_name(Session.Supervisor.get_name(@session_id))
    end)
  end

  test "Integration test, check that the UI change when the mongo db coll change", %{
    bypass: bypass
  } do
    # Setup, start env and reset coll
    coll = "init_test"
    Environment.DynamicSupervisor.ensure_env_started(@env_metadata)
    mongo_name = Environment.MongoInstance.get_full_name(@env_id)
    Mongo.drop_collection(mongo_name, coll)
    Mongo.insert_one!(mongo_name, coll, %{"foo" => "bar"})

    # Start the session and start one widget
    Session.start_session(@session_metadata, @env_metadata)

    query = %{"foo" => "bar"}

    widget_uid = %Environment.WidgetUid{
      name: "all",
      coll: coll,
      query: Jason.encode!(query),
      props: %{}
    }

    Environment.WidgetDynSup.ensure_child_started(
      @env_id,
      @session_id,
      @function_name,
      widget_uid
    )

    # Get the actual data and compare
    encoded_data = Mongo.find(mongo_name, coll, query) |> Enum.to_list() |> Jason.encode!()

    assert %{"type" => "text", "value" => ^encoded_data} =
             Environment.WidgetServer.get_widget(@env_id, widget_uid)

    # Add one more data, get it and compare
    %{inserted_id: data_id} = Mongo.insert_one!(mongo_name, coll, %{"foo" => "bar"})
    encoded_data = Mongo.find(mongo_name, coll, query) |> Enum.to_list() |> Jason.encode!()
    # Wait for the widget to receive the new data
    # TODO : Remove this and wait for the ui_builder to receive the UI
    :timer.sleep(100)

    assert %{"type" => "text", "value" => ^encoded_data} =
             Environment.WidgetServer.get_widget(@env_id, widget_uid)

    # Update the latest data and compare
    Mongo.update_one(mongo_name, coll, %{"_id" => data_id}, %{"$set" => %{"foo" => "baz"}})
    data = Mongo.find(mongo_name, coll, query) |> Enum.to_list()
    assert Enum.count(data) == 1
    encoded_data = Jason.encode!(data)
    :timer.sleep(100)

    assert %{"type" => "text", "value" => ^encoded_data} =
             Environment.WidgetServer.get_widget(@env_id, widget_uid)

    on_exit(fn ->
      Session.stop_session(@env_id, @session_id)
      Swarm.unregister_name(Session.Supervisor.get_name(@session_id))
    end)
  end
end
