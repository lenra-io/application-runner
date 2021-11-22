defmodule ApplicationRunner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    topologies = [
      example: [
        strategy: Cluster.Strategy.Gossip
        # config: [hosts: [:a@LenraBook, :b@LenraBook]]
      ]
    ]

    children = [
      # Start the json validator server for the UI
      ApplicationRunner.JsonSchemata,
      # Start the Cache Storage system (init all tables of storage)
      ApplicationRunner.Storage,

      # Start the cluster supervisor to handle all the nodes in the cluster
      {Cluster.Supervisor, [topologies, [name: LenraDataPoc.ClusterSupervisor]]},
      ApplicationRunner.AppManagers
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApplicationRunner.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
