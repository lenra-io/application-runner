defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """
  @behaviour ApplicationRunner.AdapterBehavior

  @impl true
  def get_manifest(_app) do
    {:ok, %{"widgets" => %{"root" => %{}}, "entrypoint" => "root"}}
  end

  @impl true
  def get_widget(_app, _widget, _data) do
    {:ok, %{"ui" => %{"root" => %{}}}}
  end

  @impl true
  def run_listener(_app, _listener, _data) do
    { :ok, %{} }
  end

  @impl true
  def get_data(_action) do
    {:ok,
     %ApplicationRunner.AppContext{
       user_id: 1,
       app_name: "test",
       build_number: 42,
       action_logs_uuid: "truc"
     }}
  end

  @impl true
  def save_data(_action, _data) do
    {:ok, %{}}
  end
end
