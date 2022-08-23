defmodule ApplicationRunner.Environment.WidgetDynSupTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.Environment.{
    QueryDynSup,
    WidgetDynSup,
    WidgetServer,
    WidgetUid,
    MongoInstance
  }

  alias ApplicationRunner.Environment

  alias ApplicationRunner.Widget.Context

  @widget_ui %{widget: %{"text" => "test"}}

  @function_name Ecto.UUID.generate()
  @env_id 42
  @session_id 1337
  @user_id 1

  @env_metadata %Environment.Metadata{
    env_id: @env_id,
    function_name: @function_name,
    token: "abc"
  }

  setup do
    # {:ok, _pid} = start_supervised({WidgetDynSup, env_id: @env_id})
    # {:ok, _pid} = start_supervised({QueryDynSup, env_id: @env_id})
    # {:ok, _} = start_supervised({Mongo, MongoInstance.config(@env_id)})
    {:ok, _pid} = start_supervised({Environment.Supervisor, @env_metadata})

    url = "/function/#{@function_name}"

    Bypass.open(port: 1234)
    |> Bypass.stub("POST", url, &handle_resp/1)

    on_exit(fn ->
      # Swarm.unregister_name(WidgetDynSup.get_name(@env_id))
      # Swarm.unregister_name(QueryDynSup.get_name(@env_id))
      # Swarm.unregister_name(MongoInstance.get_name(@env_id))
      Swarm.unregister_name(Environment.Supervisor.get_name(@env_id))
    end)

    :ok
  end

  defp handle_resp(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(@widget_ui))
  end

  describe "ApplicationRunner.Environments.WidgetDynSup.ensure_child_started/2" do
    test "should start widget genserver with valid opts" do
      widget_uid = %WidgetUid{name: "test", coll: "testcoll", query: "{}", props: %{}}

      assert :undefined != Swarm.whereis_name(Environment.WidgetDynSup.get_name(@env_id))

      assert {:ok, _pid} =
               WidgetDynSup.ensure_child_started(
                 @env_id,
                 @session_id,
                 @function_name,
                 widget_uid
               )

      # assert @widget_ui.widget ==
      #          WidgetServer.get_widget(@env_id, widget_uid)
    end
  end
end
