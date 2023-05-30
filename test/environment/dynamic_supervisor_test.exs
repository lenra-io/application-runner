defmodule ApplicationRunner.Environment.DynamixSupervisorTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.Contract
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Environment.DynamicSupervisor

  @function_name Ecto.UUID.generate()

  defp handle_resp(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case Jason.decode(body) do
      {:ok, _json} ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{view: @view})
        )

      {:error, _} ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{manifest: @manifest}))
    end
  end

  test "should scall to zero on environment exit" do
    {:ok, %{id: env_id}} = Repo.insert(Contract.Environment.new())

    bypass = Bypass.open(port: 1234)
    Bypass.stub(bypass, "POST", "/function/#{@function_name}", &handle_resp/1)

    env_metadata = %Environment.Metadata{
      env_id: env_id,
      function_name: @function_name
    }

    on_exit(fn ->
      Swarm.unregister_name(Environment.Supervisor.get_name(env_id))
    end)

    {:ok, _pid} = DynamicSupervisor.ensure_env_started(env_metadata)

    my_pid = self()

    Bypass.expect_once(
      bypass,
      "POST",
      "/system/scale-function/#{@function_name}",
      fn conn ->
        send(my_pid, :lookup)

        conn
        |> send_resp(200, "ok")
      end
    )

    DynamicSupervisor.stop_env(env_id)

    assert_receive(:lookup, 500)
  end
end
