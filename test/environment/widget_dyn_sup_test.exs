defmodule ApplicationRunner.Environment.WidgetDynSupTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.Environment.{
    WidgetDynSup,
    WidgetServer,
    WidgetUid
  }

  alias ApplicationRunner.{Contract, Environment, Telemetry}
  alias ApplicationRunner.Guardian.AppGuardian
  alias QueryParser.Parser

  @manifest %{"rootWidget" => "main"}
  @widget %{"type" => "text", "value" => "test"}

  @function_name Ecto.UUID.generate()
  @session_id 1337

  setup do
    {:ok, %{id: env_id}} = Repo.insert(Contract.Environment.new())

    Bypass.open(port: 1234)
    |> Bypass.stub("POST", "/function/#{@function_name}", &handle_resp/1)

    {:ok, token, claims} = AppGuardian.encode_and_sign(env_id, %{type: "env", env_id: env_id})

    env_metadata = %Environment.Metadata{
      env_id: @env_id,
      function_name: @function_name,
      token: token
    }

    {:ok, _pid} = start_supervised({Environment.Supervisor, env_metadata})

    on_exit(fn ->
      Swarm.unregister_name(Environment.Supervisor.get_name(@env_id))
    end)

    :ok
  end

  defp handle_resp(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case Jason.decode(body) do
      {:ok, _json} ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{widget: @widget})
        )

      {:error, _} ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{manifest: @manifest}))
    end
  end

  describe "ApplicationRunner.Environments.WidgetDynSup.ensure_child_started/2" do
    test "should start widget genserver with valid opts" do
      widget_uid = %WidgetUid{
        name: "test",
        coll: "testcoll",
        query_parsed: Parser.parse!("{}"),
        query_transformed: %{},
        props: %{},
        context: %{}
      }

      assert :undefined != Swarm.whereis_name(Environment.WidgetDynSup.get_name(@env_id))

      assert {:ok, _pid} =
               WidgetDynSup.ensure_child_started(
                 @env_id,
                 @session_id,
                 @function_name,
                 widget_uid
               )

      assert @widget == WidgetServer.fetch_widget!(@env_id, widget_uid)
    end
  end
end
