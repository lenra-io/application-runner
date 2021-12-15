defmodule ApplicationRunner.SessionSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    children =
      [
        ApplicationRunner.CacheAsync,
      ] ++ Application.get_env(:application_runner, :additional_session_modules, [])

    Supervisor.init(children, strategy: :one_for_one)
  end
end
