defmodule ApplicationRunner.AppManagerTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.AppManager` module
  """

  alias ApplicationRunner.{AppManagers, AppManager, MockGenServer}

  setup do
    start_supervised(AppManagers)
    :ok
  end

  test "Can AppManager supervisor should exist and have the MockGenServer." do
    assert {:ok, pid} = AppManagers.start_app(1)
    assert {:ok, _pid} = AppManager.fetch_module_pid(pid, MockGenServer)
  end

  test "Can AppManager supervisor should not have the NotExistGenServer" do
    assert {:ok, pid} = AppManagers.start_app(1)

    assert_raise(
      RuntimeError,
      "No such Module in AppSupervisor. This should not happen.",
      fn -> AppManager.fetch_module_pid(pid, NotExistGenServer) end
    )
  end
end
