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
           }
         }
    test "Special listeners are optionnal. Nothing happen if not set." do
      refute_receive({:ui, _})
      refute_receive({:error, _})
    end
  end

  describe "SessionManager.fetch_assigns/set_assigns" do
    test "Set assign then get retrive the same data", %{session_id: session_id} do
      SessionManager.set_assigns(session_id, %{foo: "bar"})
      assert {:ok, %{foo: "bar"}} = SessionManager.fetch_assigns(session_id)
    end
  end
end
