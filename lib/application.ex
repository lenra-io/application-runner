defmodule ApplicationRunner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    children =
      [
        # Start the json validator server for the UI
        ApplicationRunner.JsonSchemata,
        ApplicationRunner.EnvManagers,
        ApplicationRunner.SessionManagers,
        ApplicationRunner.Storage
      ] ++
        if Mix.env() == :test do
          [ApplicationRunner.Repo]
        else
          []
        end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApplicationRunner.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
