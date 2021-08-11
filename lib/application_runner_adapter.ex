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
    {:ok, %{}}
  end

  @impl ApplicationRunner.AdapterBehavior
  def save_data(_action, _data) do
    {:ok, %{}}
  end
end
