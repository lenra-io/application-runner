defmodule ApplicationRunner.AppManagersTest do
  use ExUnit.Case, async: false

  @moduledoc """
    Test the `ApplicationRunner.AppManagers` module
  """

  alias ApplicationRunner.{AppManagers}

  setup do
    start_supervised(AppManagers)
    :ok
  end

  test "Can start one App" do
    assert {:ok, _} = AppManagers.start_app(1)
  end

  test "Can start multiple Apps" do
    1..10
    |> Enum.to_list()
    |> Enum.each(fn app_id ->
      assert {:ok, _} = AppManagers.start_app(app_id)
    end)
  end

  test "Can start one App and get it after" do
    assert {:error, :app_not_started} = AppManagers.fetch_app_manager_pid(1)
    assert {:ok, pid} = AppManagers.start_app(1)
    assert {:ok, ^pid} = AppManagers.fetch_app_manager_pid(1)
  end

  test "Cannot start same app twice" do
    assert {:ok, pid} = AppManagers.start_app(1)
    assert {:error, {:already_started, ^pid}} = AppManagers.start_app(1)
  end
end
