defmodule ApplicationRunner.IntegrationTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.{AppChannel, Contract, Environment, MongoStorage, Session}

  @session_id Ecto.UUID.generate()
  @function_name Ecto.UUID.generate()
  @url "/function/#{@function_name}"
  @coll "test_integration"
  @query %{"foo" => "bar"}

  @manifest %{"rootWidget" => "main"}

  def widget("main", _) do
    %{"type" => "widget", "name" => "echo", "query" => @query, "coll" => @coll}
  end

  def widget("echo", data) do
    %{"type" => "text", "value" => Jason.encode!(data)}
  end

  setup do
    ctx = %{}
    ctx = Map.merge(ctx, setup_db(ctx))
    ctx = Map.merge(ctx, setup_bypass(ctx))
    ctx = Map.merge(ctx, setup_env_metadata(ctx))
    ctx = Map.merge(ctx, setup_session_metadata(ctx))

    {:ok, ctx}
  end

  def setup_db(_ctx) do
    {:ok, env} = ApplicationRunner.Repo.insert(Contract.Environment.new(%{}))
    {:ok, user} = ApplicationRunner.Repo.insert(Contract.User.new(%{email: "test@test.te"}))
    %{user: user, env: env}
  end

  def setup_session_metadata(%{env: env, user: user}) do
    %{
      session_metadata: %Session.Metadata{
        env_id: env.id,
        user_id: user.id,
        session_id: @session_id,
        function_name: @function_name,
        token: AppChannel.do_create_session_token(env.id, @session_id, user.id) |> elem(1)
      }
    }
  end

  def setup_env_metadata(%{env: env}) do
    %{
      env_metadata: %Environment.Metadata{
        env_id: env.id,
        function_name: @function_name,
        token: AppChannel.do_create_env_token(env.id) |> elem(1)
      }
    }
  end

  def setup_bypass(_ctx) do
    bypass =
      Bypass.open(port: 1234)
      |> Bypass.stub("POST", @url, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        case Jason.decode(body) do
          {:ok, %{"action" => _}} ->
            Plug.Conn.resp(
              conn,
              200,
              Jason.encode!(:ok)
            )

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

    %{bypass: bypass}
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

  test "Integration test, check that the UI change when the mongo db coll change", %{
    env_metadata: em,
    session_metadata: sm
  } do
    # Self must join AppChannel group to receive new UI
    Swarm.register_name(AppChannel.get_name(sm.session_id), self())
    Swarm.join(AppChannel.get_group(sm.session_id), self())

    # Start env
    Environment.DynamicSupervisor.ensure_env_started(em)
    # Reset and setup mongo coll
    mongo_name = Environment.MongoInstance.get_full_name(em.env_id)
    Mongo.drop_collection(mongo_name, @coll)
    Mongo.insert_one!(mongo_name, @coll, %{"foo" => "bar"})

    # The mongo_user_link should not exist before starting the session
    assert not MongoStorage.has_user_link?(em.env_id, sm.user_id)

    # Start the session and start one widget
    Session.start_session(sm, em)

    # The mongo_user_link should have been creating when starting session.
    assert MongoStorage.has_user_link?(em.env_id, sm.user_id)

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
      Session.stop_session(em.env_id, sm.session_id)
      Swarm.unregister_name(Session.Supervisor.get_name(sm.session_id))
    end)
  end
end
