defmodule ApplicationRunner.Environment.WidgetDynSupTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.Environment.WidgetDynSup

  alias ApplicationRunner.{Environment, Session}

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

  @session_metadata %Session.Metadata{
    session_id: @session_id,
    env_id: @env_id,
    user_id: @user_id,
    function_name: @function_name,
    token: "abc",
    socket_pid: self()
  }

  setup do
    {:ok, _pid} = start_supervised({WidgetDynSup, @env_metadata})
    url = "/function/#{@function_name}"

    Bypass.open(port: 1234)
    |> Bypass.stub("POST", url, &handle_resp/1)

    :ok
  end

  defp handle_resp(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(@widget_ui))
  end

  describe "ApplicationRunner.Environments.WidgetDynSup.ensure_child_started_1/1" do
    test "should start widget genserver with valid opts" do
      current_widget = %Context{id: 1, name: "test", prefix_path: ""}

      assert :ok =
               WidgetDynSup.ensure_child_started(
                 @session_metadata,
                 current_widget
               )

      name = "#{@session_metadata.env_id}_#{current_widget.name}"

      assert {:ok, @widget_ui.widget} ==
               GenServer.call({:via, :swarm, name}, :get_widget)
    end
  end
end
