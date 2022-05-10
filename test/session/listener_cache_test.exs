defmodule ApplicationRunner.ListenerCacheTest do
  use ExUnit.Case, async: false

  alias ApplicationRunner.{
    EnvManagers,
    ListenersCache,
    SessionManagers
  }

  setup do
    start_supervised(EnvManagers)
    start_supervised(SessionManagers)

    {:ok, pid} = SessionManagers.start_session(make_ref(), make_ref(), %{}, %{})

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
