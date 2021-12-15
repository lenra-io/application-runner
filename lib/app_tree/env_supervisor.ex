defmodule ApplicationRunner.EnvSupervisor do
  @moduledoc """
    This module handle the children module of an AppManager.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true

  def init(_opts) do
    children =
      [
        # ApplicationRunner.WidgetCache
      ] ++ Application.get_env(:application_runner, :additional_app_modules, [])

    Supervisor.init(children, strategy: :one_for_one)
  end
end
