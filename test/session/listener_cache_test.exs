defmodule ApplicationRunner.ListenerCacheTest do
  use ApplicationRunner.RepoCase, async: false

  alias ApplicationRunner.{
    Environment,
    EnvManagers,
    ListenersCache,
    Repo,
    SessionManagers,
    User
  }

  setup do
    start_supervised(EnvManagers)
    start_supervised(SessionManagers)

    {:ok, env} = Repo.insert(Environment.new())
    {:ok, user} = Repo.insert(User.new("test@test.te"))

    bypass = Bypass.open()
    Bypass.stub(bypass, "POST", "/function/test_function", &Plug.Conn.resp(&1, 200, "{}"))

    Application.put_env(:application_runner, :faas_url, "http://localhost:#{bypass.port}")

    {:ok, pid} =
      SessionManagers.start_session(
        Ecto.UUID.generate(),
        env.id,
        %{
          user_id: user.id,
          function_name: "test_function",
          assigns: %{socket_pid: self()}
        },
        %{
          function_name: "test_function",
          assigns: %{}
        }
      )

    {:ok, %{session_state: :sys.get_state(pid)}}
  end

  test "test save_listener and fetch_listener", %{session_state: session_state} do
    action = "go"
    props = %{"value" => "ok"}

    listener = %{
      "action" => action,
      "props" => props
    }

    code = Crypto.hash({action, props})

    assert {:error, :no_listener_with_code} ==
             ListenersCache.fetch_listener(session_state, code)

    assert :ok == ListenersCache.save_listener(session_state, code, listener)
    assert {:ok, listener} == ListenersCache.fetch_listener(session_state, code)
  end
end
