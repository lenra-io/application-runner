defmodule ApplicationRunner.Environment.WidgetTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.Environment.Widget

  alias ApplicationRunner.Session.State

  alias ApplicationRunner.Widget.Context

  alias LenraCommon.Errors.TechnicalError

  @widget_ui %{widget: %{"text" => "test"}}

  setup do
    function_name = Ecto.UUID.generate()
    url = "/function/#{function_name}"

    bypass = Bypass.open(port: 1234)
    Bypass.stub(bypass, "POST", url, &handle_resp/1)

    {:ok, function_name: function_name, bypass: bypass}
  end

  defp handle_resp(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(@widget_ui))
  end

  describe "ApplicationRunner.Environment.Widget_1/1" do
    test "should start GenServer with valid opts", %{function_name: function_name} do
      session_state = %State{session_id: 1, env_id: 1, user_id: 1, function_name: function_name}
      current_widget = %Context{id: 1, name: "test", prefix_path: ""}
      {:ok, pid} = Widget.start_link(session_state: session_state, current_widget: current_widget)
      assert is_pid(pid)
    end

    # test "should return error if openfass not reachable", %{
    #   function_name: function_name,
    #   bypass: bypass
    # } do
    #   Bypass.down(bypass)

    #   session_state = %State{
    #     session_id: 1,
    #     env_id: 1,
    #     user_id: 1,
    #     function_name: function_name
    #   }

    #   current_widget = %Context{id: 1, name: "test", prefix_path: ""}

    #   Process.flag(:trap_exit, true)

    #   assert_raise TechnicalError,
    #                "Openfaas could not be reached.",
    #                Widget.start_link(session_state: session_state, current_widget: current_widget)
    # end
  end

  test "call get_widget on widget genserver", %{function_name: function_name} do
    session_state = %State{session_id: 1, env_id: 1, user_id: 1, function_name: function_name}
    current_widget = %Context{id: 1, name: "test", prefix_path: ""}

    {:ok, pid} = Widget.start_link(session_state: session_state, current_widget: current_widget)

    name = "#{session_state.env_id}_#{current_widget.name}"

    assert {:ok, @widget_ui.widget} ==
             GenServer.call({:via, :swarm, name}, :get_widget)
  end
end
