defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """
  @behaviour ApplicationRunner.AdapterBehavior

  @impl ApplicationRunner.AdapterBehavior
  def run_action(_action) do
    {:ok, %{"data" => %{}, "ui" => %{"root" => %{}}}}
  end

  @impl ApplicationRunner.AdapterBehavior
  def get_data(_action) do
    {:ok,
     %ApplicationRunner.Action{
       user_id: 1,
       app_name: "test",
       build_number: 42,
       action_logs_uuid: "truc"
     }}
  end

  @impl ApplicationRunner.AdapterBehavior
  def save_data(_action, _data) do
    {:ok, %{}}
  end
end
