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

  def init_data(_, _) do
    %{}
  end

  describe "SessionManager.send_special_event/2" do
    @tag mock: %{
           widgets: %{
             "root" => &__MODULE__.my_widget/2
           },
           listeners: %{"InitData" => &__MODULE__.init_data/2}
         }
    test "should call the InitData listener", %{
      session_state: _session_state,
      session_pid: session_pid
    } do
      ApplicationRunner.SessionManager.send_special_event(session_pid, "InitData", %{})

      refute_receive({:ui, _})
      refute_receive({:error, _})
    end

    @tag mock: %{
           widgets: %{
             "root" => &__MODULE__.my_widget/2
           },
           listeners: %{}
         }
    test "should return error if listeners InitData not found", %{
      session_state: _session_state,
      session_pid: session_pid
    } do
      ApplicationRunner.SessionManager.send_special_event(session_pid, "InitData", %{})

      assert_receive({:error, {:error, :listener_not_found}})
    end
  end
end
