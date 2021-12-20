defmodule ApplicationRunner.EnvManagerTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.AppManager` module
  """

  alias ApplicationRunner.{EnvManagers, EnvManager, MockGenServer}

  setup do
    start_supervised(EnvManagers)
    :ok
  end

  test "Can EnvManager supervisor should exist and have the MockGenServer." do
    assert {:ok, pid} = EnvManagers.start_env(1, 1, "app")
    assert {:ok, _pid} = EnvManager.fetch_module_pid(pid, MockGenServer)
  end

  test "Can EnvManager supervisor should not have the NotExistGenServer" do
    assert {:ok, pid} = EnvManagers.start_env(1, 1, "app")

    assert_raise(
      RuntimeError,
      "No such Module in EnvSupervisor. This should not happen.",
      fn -> EnvManager.fetch_module_pid(pid, NotExistGenServer) end
    )
  end
end
