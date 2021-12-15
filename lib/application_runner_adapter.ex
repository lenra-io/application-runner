defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """
  @behaviour ApplicationRunner.AdapterBehavior

  alias ApplicationRunner.{SessionState}

  @impl true
  def get_manifest(_app) do
    {:ok, %{"widgets" => %{"root" => %{}}, "entrypoint" => "root"}}
  end

  @impl true
  def get_widget(_app, _widget, _data) do
    {:ok, %{"root" => %{}}}
  end

  @impl true
  def run_listener(_app, _listener, _data) do
    {:ok, %{}}
  end

  @impl true
  def get_data(%SessionState{} = _session_state) do
    {:ok, %{}}
  end

  @impl true
  def save_data(%SessionState{} = _session_state, _data) do
    :ok
  end
end
