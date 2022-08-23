defmodule ApplicationRunner.Environment.WidgetTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.Environment.{QueryDynSup, MongoInstance, WidgetServer, WidgetUid}
  alias ApplicationRunner.Environment

  alias ApplicationRunner.Session

  alias ApplicationRunner.Widget.Context

  @env_id 42
  @widget_ui %{widget: %{"text" => "test"}}
  @function_name Ecto.UUID.generate()
  @url "/function/#{@function_name}"

  @env_metadata %Environment.Metadata{
    env_id: @env_id,
    function_name: @function_name,
    token: "abc"
  }

  setup do
    {:ok, _pid} = start_supervised({Environment.Supervisor, @env_metadata})

    bypass = Bypass.open(port: 1234)
    Bypass.stub(bypass, "POST", @url, &handle_resp/1)

    on_exit(fn ->
      Swarm.unregister_name(Environment.Supervisor.get_name(@env_id))
    end)

    {:ok, %{bypass: bypass}}
  end

  defp handle_resp(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(@widget_ui))
  end
end
