defmodule ApplicationRunner.EnvironmentTest do
  use ExUnit.Case

  alias ApplicationRunner.{Environment, Session}

  @step1_ui %{widget: %{"text" => "test1"}}
  @step2_ui %{widget: %{"text" => "test2"}}

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
    token: "abcd",
    socket_pid: self()
  }

  setup do
    bypass = Bypass.open(port: 1234)
    Bypass.stub(bypass, "POST", @url, &handle_resp/1)

    {:ok, %{bypass: bypass}}
  end

  defp handle_resp(conn) do
    # {:ok, body} = Plug.Conn.read_body(conn)
    # json = Jason.decode!(body)
    Plug.Conn.resp(conn, 200, Jason.encode!(@step1_ui))
  end

  test "Check that all dependancies are started and correctly named" do
    Session.start_session(@session_metadata, @env_metadata)

    assert :undefined != Swarm.whereis_name(Environment.Supervisor.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.MetadataAgent.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.MongoInstance.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.ChangeStream.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.QueryDynSup.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Environment.WidgetDynSup.get_name(@env_id))
    assert :undefined != Swarm.whereis_name(Session.DynamicSupervisor.get_name(@env_id))

    assert :undefined != Swarm.whereis_name(Session.MetadataAgent.get_name(@session_id))
    assert :undefined != Swarm.whereis_name(Session.ChangeEventManager.get_name(@session_id))
  end
end
