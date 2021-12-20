defmodule ApplicationRunner.EnvManagersTest do
  use ExUnit.Case, async: false
  alias ApplicationRunner.{EnvManagers, ListenersHandler}

  setup do
    start_supervised(EnvManagers)

    {:ok, pid} = EnvManagers.start_env(1, 1, "app")

    {:ok, %{env_state: :sys.get_state(pid)}}
  end

  test "test build listeners", %{env_state: env_state} do
    comp = %{
      "type" => "button",
      "onPressed" => %{
        "action" => "go",
        "props" => %{"value" => "ok"}
      }
    }

    binary = :erlang.term_to_binary("go") <> :erlang.term_to_binary(%{"value" => "ok"})
    expected_code = :crypto.hash(:sha256, binary) |> Base.encode64()

    assert {:ok, %{"code" => ^expected_code}} =
             ListenersHandler.build_listeners(env_state, comp, ["onPressed"])
  end
end
