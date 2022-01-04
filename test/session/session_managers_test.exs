defmodule ApplicationRunner.SessionManagersTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.SessionManagersTest` module
  """

  alias ApplicationRunner.{EnvManagers, SessionManagers}

  setup do
    start_supervised(EnvManagers)
    start_supervised(SessionManagers)
    :ok
  end

  test "Can start one Session" do
    assert {:ok, _} = SessionManagers.start_session(make_ref(), make_ref(), 1, "app")
  end

  test "Can start multiple Sessions" do
    1..10
    |> Enum.to_list()
    |> Enum.each(fn _ ->
      assert {:ok, _} = SessionManagers.start_session(make_ref(), make_ref(), 1, "app")
    end)
  end

  test "Can start one session and get it after" do
    session_id = make_ref()
    env_id = make_ref()
    assert {:error, :session_not_started} = SessionManagers.fetch_session_manager_pid(session_id)
    assert {:ok, pid} = SessionManagers.start_session(session_id, env_id, 1, "app")
    assert {:ok, ^pid} = SessionManagers.fetch_session_manager_pid(session_id)
  end

  test "Cannot start same session twice" do
    session_id = make_ref()
    env_id = make_ref()
    assert {:ok, pid} = SessionManagers.start_session(session_id, env_id, 1, "app")

    assert {:error, {:already_started, ^pid}} =
             SessionManagers.start_session(session_id, env_id, 1, "app")
  end
end
