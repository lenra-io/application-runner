defmodule ApplicationRunner.ComponentCase do
  @moduledoc """
    This is a ExUnit test case with some setup that allow simpler unit test on JSON UI.

    ```
      use ApplicationRunner.ComponentCase
    ```
  """
  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: false

      alias ApplicationRunner.{
        ApplicationRunnerAdapter,
        EnvManager,
        EnvManagers,
        SessionManagers,
        SessionManager
      }

      setup context do
        start_supervised(EnvManagers)
        start_supervised(SessionManagers)
        start_supervised(ApplicationRunnerAdapter)
        session_id = make_ref()
        env_id = make_ref()

        if context[:mock] != nil do
          ApplicationRunnerAdapter.set_mock(context[:mock])
        end

        {:ok, pid} = SessionManagers.start_session(session_id, env_id, %{test_pid: self()}, %{})

        session_state = :sys.get_state(pid)

        on_exit(fn ->
          EnvManagers.stop_env(env_id)
        end)

        %{session_state: session_state, session_pid: pid, session_id: session_id, env_id: env_id}
      end

      def mock_root_and_run(json, session_id) do
        ApplicationRunnerAdapter.set_mock(%{widgets: %{"root" => fn _, _ -> json end}})
        SessionManager.reload_ui(session_id)
      end

      defmacro assert_success(expected) do
        quote do
          assert_receive {:ui, %{"root" => res}}
          assert unquote(expected) = res
        end
      end

      defmacro assert_error(expected) do
        quote do
          assert_receive {:error, res}
          assert res = unquote(expected)
        end
      end
    end
  end
end
