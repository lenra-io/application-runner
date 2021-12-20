defmodule ApplicationRunner.SessionManagerTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.SessionManagerTest` module
  """

  alias ApplicationRunner.{
    EnvManagers,
    SessionManagers,
    SessionManager,
    MockGenServer,
    SessionState
  }

  setup do
    start_supervised(EnvManagers)
    start_supervised(SessionManagers)
    :ok
  end

  test "SessionManager supervisor should exist and have the MockGenServer." do
    assert {:ok, pid} = SessionManagers.start_session("1", 1, 1, "app")

    assert {:ok, _pid} =
             SessionManager.fetch_module_pid(
               :sys.get_state(pid),
               MockGenServer
             )
  end

  test "SessionManager supervisor should not have the NotExistGenServer" do
    assert {:ok, pid} = SessionManagers.start_session("1", 1, 1, "app")

    assert_raise(
      RuntimeError,
      "No such Module in SessionSupervisor. This should not happen.",
      fn ->
        SessionManager.fetch_module_pid(
          :sys.get_state(pid),
          NotExistGenServer
        )
      end
    )
  end
end
