defmodule ApplicationRunner.EnvManagersTest do
  use ApplicationRunner.RepoCase, async: false

  @moduledoc """
    Test the `ApplicationRunner.EnvManagers` module
  """

  alias ApplicationRunner.{Environment, EnvManager, EnvManagers, Repo}

  setup do
    start_supervised(EnvManagers)

    start_supervised({Finch, name: AppHttp})

    bypass = Bypass.open()
    Bypass.stub(bypass, "POST", "/function/test_function", &handle_request(&1))

    Application.put_env(:application_runner, :faas_url, "http://localhost:#{bypass.port}")

    {:ok, env} = Repo.insert(Environment.new())
    {:ok, env_id: env.id}
  end

  defp handle_request(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(%{"manifest" => %{}}))
  end

  test "Can start one Env", %{env_id: env_id} do
    assert {:ok, _} =
             EnvManagers.start_env(env_id, %{
               function_name: "test_function",
               assigns: %{}
             })

    assert :ok = EnvManager.wait_until_ready(env_id)
  end

  test "Can start multiple Envs", %{env_id: _env_id} do
    1..10
    |> Enum.to_list()
    |> Enum.each(fn _ ->
      {:ok, env} = Repo.insert(Environment.new())

      assert {:ok, _} =
               EnvManagers.start_env(env.id, %{
                 function_name: "test_function",
                 assigns: %{}
               })

      assert :ok = EnvManager.wait_until_ready(env.id)
    end)
  end

  test "Can start one Env and get it after", %{env_id: env_id} do
    assert {:error, :env_not_started} = EnvManagers.fetch_env_manager_pid(env_id)

    assert {:ok, pid} =
             EnvManagers.start_env(env_id, %{
               function_name: "test_function",
               assigns: %{}
             })

    assert {:ok, ^pid} = EnvManagers.fetch_env_manager_pid(env_id)
    assert :ok = EnvManager.wait_until_ready(env_id)
  end

  test "Cannot start same env twice", %{env_id: env_id} do
    assert {:ok, pid} =
             EnvManagers.start_env(env_id, %{
               function_name: "test_function",
               assigns: %{}
             })

    assert :ok = EnvManager.wait_until_ready(env_id)

    assert {:error, {:already_started, ^pid}} =
             EnvManagers.start_env(env_id, %{
               function_name: "test_function",
               assigns: %{}
             })
  end
end
