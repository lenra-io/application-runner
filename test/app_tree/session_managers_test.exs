defmodule ApplicationRunner.SessionManagersTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.SessionManagersTest` module
  """

  alias ApplicationRunner.{AppManagers, SessionManagers}

  setup do
    start_supervised(AppManagers)
    start_supervised(SessionManagers)
    :ok
  end

  test "Can start one Session" do
    assert {:ok, _} = SessionManagers.start_session(1, "1")
  end

  test "Can start multiple Sessions" do
    1..10
    |> Enum.to_list()
    |> Enum.each(fn session_id ->
      assert {:ok, _} = SessionManagers.start_session(1, session_id)
    end)
  end

  test "Can start one session and get it after" do
    assert {:error, :session_not_started} = SessionManagers.fetch_session_manager_pid("1")
    assert {:ok, pid} = SessionManagers.start_session(1, "1")
    assert {:ok, ^pid} = SessionManagers.fetch_session_manager_pid("1")
  end

  test "Cannot start same session twice" do
    assert {:ok, pid} = SessionManagers.start_session(1, "1")
    assert {:error, {:already_started, ^pid}} = SessionManagers.start_session(1, "1")
  end
end
