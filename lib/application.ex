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
        ApplicationRunner.Environment.DynamicSupervisor,
        {Finch,
         name: AppHttp,
         pools: %{
           Application.fetch_env!(:application_runner, :faas_url) => [size: 32, count: 8]
         }}
      ] ++ test_only_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApplicationRunner.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def test_only_children() do
    if Mix.env() == :test do
      [
        ApplicationRunner.FakeEndpoint
      ]
    else
      []
    end
  end
end
