defmodule ApplicationRunner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      # Start the json validator server for the UI
      ApplicationRunner.JsonSchemata,
      ApplicationRunner.Scheduler,
      ApplicationRunner.Environment.DynamicSupervisor,
      {Finch,
       name: AppHttp,
       pools: %{
         Application.fetch_env!(:application_runner, :faas_url) => [size: 32, count: 8]
       }}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApplicationRunner.Supervisor]

    Supervisor.init(children, opts)
  end
end
