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
        SessionManagers
      }

      setup do
        start_supervised(EnvManagers)
        start_supervised(SessionManagers)
        # start session
        # These make_ref() create a uniq ref that avoid collision across two test.
        session_id = make_ref()
        env_id = make_ref()
        {:ok, pid} = SessionManagers.start_session(session_id, env_id, 1, "app")
        session_state = :sys.get_state(pid)

        on_exit(fn ->
          SessionManagers.stop_session(session_id)
          EnvManagers.stop_env(env_id)
        end)

        %{session_state: session_state}
      end

      def mock_root_and_run(json, session_state) do
        ApplicationRunnerAdapter.set_mock(%{widgets: %{"root" => fn _, _ -> json end}})
        EnvManager.get_and_build_ui(session_state, "root", %{})
      end

      defmacro assert_success(expected, actual) do
        quote do
          assert {:ok, res} = unquote(actual)
          assert %{"entrypoint" => entrypoint} = res
          assert %{"widgets" => %{^entrypoint => widget}} = res
          assert unquote(expected) = widget
        end
      end

      defmacro assert_error(expected, actual) do
        quote do
          assert unquote(expected) = unquote(actual)
        end
      end
    end
  end
end
