defmodule ApplicationRunner.SessionManagerTest do
  use ApplicationRunner.ComponentCase

  @moduledoc """
    Test the `ApplicationRunner.SessionManagerTest` module
  """

  alias ApplicationRunner.{
    MockGenServer,
    SessionManager,
    SessionManagers
  }

  test "SessionManager supervisor should exist and have the MockGenServer." do
    assert {:ok, pid} = SessionManagers.start_session(make_ref(), make_ref(), %{user: %{}}, %{})

    assert _pid =
             SessionManager.fetch_module_pid!(
               :sys.get_state(pid),
               MockGenServer
             )
  end

  test "SessionManager supervisor should not have the NotExistGenServer" do
    assert {:ok, pid} = SessionManagers.start_session(make_ref(), make_ref(), %{user: %{}}, %{})

    assert_raise(
      RuntimeError,
      "No such Module in SessionSupervisor. This should not happen.",
      fn ->
        SessionManager.fetch_module_pid!(
          :sys.get_state(pid),
          NotExistGenServer
        )
      end
    )
  end

  def my_widget(_, _) do
    %{
      "type" => "flex",
      "children" => []
    }
  end

  def init_data(_, _, _) do
    %{}
  end

  describe "SessionManager.initData/2" do
    @tag mock: %{
           widgets: %{
             "root" => &__MODULE__.my_widget/2
           },
           listeners: %{"InitData" => &__MODULE__.init_data/3}
         }
    test "should return ui if listeners correct", %{
      session_state: _session_state,
      session_pid: session_pid
    } do
      ApplicationRunner.SessionManager.init_data(session_pid)

      assert_receive(
        {:ui,
         %{
           "root" => %{
             "type" => "flex",
             "children" => []
           }
         }}
      )
    end

    @tag mock: %{
           widgets: %{
             "root" => &__MODULE__.my_widget/2
           },
           listeners: %{}
         }
    test "should return error if listeners initData not found", %{
      session_state: _session_state,
      session_pid: session_pid
    } do
      ApplicationRunner.SessionManager.init_data(session_pid)

      assert_receive({:error, {:error, :listener_not_found}})
    end
  end
end
