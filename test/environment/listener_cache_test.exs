defmodule ApplicationRunner.ListenerCacheTest do
  use ExUnit.Case, async: false
  alias ApplicationRunner.{EnvManagers, ListenersCache}

  setup do
    start_supervised(EnvManagers)

    {:ok, pid} = EnvManagers.start_env(make_ref(), 1, "app")

    {:ok, %{env_state: :sys.get_state(pid)}}
  end

  test "test generate_listeners_key", %{env_state: _env_state} do
    action = "go"
    props = %{"value" => "ok"}
    almost_props = %{"value" => "ok."}
    almost_action = "go."

    assert is_binary(ListenersCache.generate_listeners_key(action, props))

    assert not (ListenersCache.generate_listeners_key(action, props) ==
                  ListenersCache.generate_listeners_key(almost_action, props))

    assert not (ListenersCache.generate_listeners_key(action, props) ==
                  ListenersCache.generate_listeners_key(action, almost_props))
  end

  test "test save_listener and get_listener", %{env_state: env_state} do
    action = "go"
    props = %{"value" => "ok"}

    listener = %{
      "action" => action,
      "props" => props
    }

    code = ListenersCache.generate_listeners_key(action, props)

    assert_raise(
      RuntimeError,
      "No listener found with code #{code}",
      fn -> ListenersCache.get_listener(env_state, code) end
    )

    assert :ok == ListenersCache.save_listener(env_state, code, listener)
    assert listener == ListenersCache.get_listener(env_state, code)
  end
end
