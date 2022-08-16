defmodule ApplicationRunner.Environment.Widget.DynamicSupervisorTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.Environment.Widget.DynamicSupervisor

  alias ApplicationRunner.Session.State

  alias ApplicationRunner.Widget.Context

  @widget_ui %{widget: %{"text" => "test"}}

  setup do
    DynamicSupervisor.start_link(%{})
    function_name = Ecto.UUID.generate()
    url = "/function/#{function_name}"

    Bypass.open(port: 1234)
    |> Bypass.stub("POST", url, &handle_resp/1)

    {:ok, function_name: function_name}
  end

  defp handle_resp(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(@widget_ui))
  end

  describe "AppicationRunner.Environments.Widget.DynamicSupervisor.ensure_child_started_1/1" do
    test "should start widget genserver with valid opts", %{function_name: function_name} do
      session_state = %State{session_id: 1, env_id: 1, user_id: 1, function_name: function_name}
      current_widget = %Context{id: 1, name: "test", prefix_path: ""}

      assert :ok =
               DynamicSupervisor.ensure_child_started(
                 session_state,
                 current_widget
               )

      name = "#{session_state.env_id}_#{current_widget.name}"

      assert {:ok, @widget_ui.widget} ==
               GenServer.call({:via, :swarm, name}, :get_widget)
    end
  end
end
