defmodule ApplicationRunner.EnvManagersTest do
  use ApplicationRunner.RepoCase, async: false

  @moduledoc """
    Test the `ApplicationRunner.EnvManagers` module
  """

  alias ApplicationRunner.{Environment, EnvManagers, FaasStub, Repo}

  setup do
    start_supervised(EnvManagers)

    faas = FaasStub.create_faas_stub()
    Bypass.stub(faas, "POST", "/function/test_function", &handle_request(&1))

    {:ok, env} = Repo.insert(Environment.new())
    {:ok, env_id: env.id}
  end

  defp handle_request(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(%{"manifest" => %{}}))
  end

  test "Can start one Env", %{env_id: env_id} do
    assert {:ok, _} =
             EnvManagers.start_env(make_ref(), %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })
  end

  test "Can start multiple Envs", %{env_id: env_id} do
    1..10
    |> Enum.to_list()
    |> Enum.each(fn _ ->
      {:ok, env} = Repo.insert(Environment.new())

      assert {:ok, _} =
               EnvManagers.start_env(make_ref(), %{
                 env_id: env.id,
                 function_name: "test_function",
                 assigns: %{}
               })
    end)
  end

  test "Can start one Env and get it after", %{env_id: env_id} do
    env = make_ref()
    assert {:error, :env_not_started} = EnvManagers.fetch_env_manager_pid(env)

    assert {:ok, pid} =
             EnvManagers.start_env(env, %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })

    assert {:ok, ^pid} = EnvManagers.fetch_env_manager_pid(env)
  end

  test "Cannot start same env twice", %{env_id: env_id} do
    env = make_ref()

    assert {:ok, pid} =
             EnvManagers.start_env(env, %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })

    assert {:error, {:already_started, ^pid}} =
             EnvManagers.start_env(env, %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })
  end
end
