defmodule ApplicationRunner.EnvManagerTest do
  use ApplicationRunner.RepoCase, async: false

  @moduledoc """
    Test the `ApplicationRunner.AppManager` module
  """

  alias ApplicationRunner.{
    ApplicationRunnerAdapter,
    Environment,
    EnvManager,
    EnvManagers,
    EnvSupervisor,
    FaasStub,
    MockGenServer,
    Repo
  }

  @manifest %{"rootWidget" => "root"}

  setup do
    start_supervised(EnvManagers)

    faas = FaasStub.create_faas_stub()
    Bypass.stub(faas, "POST", "/function/test_function", &handle_request(&1))

    {:ok, env} = Repo.insert(Environment.new())
    {:ok, env_id: env.id}
  end

  defp handle_request(conn) do
    Plug.Conn.resp(conn, 200, Jason.encode!(%{"manifest" => %{"rootWidget" => "root"}}))
  end

  test "Can EnvManager supervisor should exist and have the MockGenServer.", %{env_id: env_id} do
    assert {:ok, pid} =
             EnvManagers.start_env(make_ref(), %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })

    env_state = :sys.get_state(pid)

    assert is_pid(EnvSupervisor.fetch_module_pid!(env_state.env_supervisor_pid, MockGenServer))
  end

  test "Can EnvManager supervisor should not have the NotExistGenServer", %{env_id: env_id} do
    assert {:ok, pid} =
             EnvManagers.start_env(make_ref(), %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })

    env_state = :sys.get_state(pid)

    assert_raise(
      RuntimeError,
      "No such Module in EnvSupervisor. This should not happen.",
      fn -> EnvSupervisor.fetch_module_pid!(env_state.env_supervisor_pid, NotExistGenServer) end
    )
  end

  test "get_manifest call the get_manifest of the adapter", %{env_id: env_id} do
    env = make_ref()

    assert {:ok, _pid} =
             EnvManagers.start_env(env, %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })

    assert @manifest == EnvManager.get_manifest(env)
  end

  test "EnvManager should stop if EnvSupervisor is killed.", %{env_id: env_id} do
    assert {:ok, pid} =
             EnvManagers.start_env(make_ref(), %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })

    env_state = :sys.get_state(pid)
    env_supervisor_pid = Map.fetch!(env_state, :env_supervisor_pid)
    assert Process.alive?(env_supervisor_pid)
    assert Process.alive?(pid)

    Process.exit(env_supervisor_pid, :kill)
    assert not Process.alive?(env_supervisor_pid)
    assert not Process.alive?(pid)
  end

  test "EnvManager should exist in Swarm group :envs", %{env_id: env_id} do
    assert {:ok, pid} =
             EnvManagers.start_env(make_ref(), %{
               env_id: env_id,
               function_name: "test_function",
               assigns: %{}
             })

    assert Enum.member?(Swarm.members(:envs), pid)
  end
end
