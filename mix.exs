defmodule ApplicationRunner.MixProject do
  use Mix.Project

  def project do
    [
      app: :application_runner,
      version: "0.0.0-dev",
      elixir: "~> 1.12",
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:ex_unit]],
      aliases: [
        test: "test"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ApplicationRunner.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "priv/repo"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_component_schema,
       git: "https://github.com/lenra-io/ex_component_schema", ref: "update-poison"},
      {:jason, "~> 1.2"},
      {:json_diff, "~> 0.1"},
      {:swarm, "~> 3.0"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, "~> 0.15.8", only: [:test], runtime: false},
      {:guardian, "~> 2.1.1"},
      {:phoenix, "~> 1.5.9"},
      {:finch, "~> 0.12"},
      {:bypass, "~> 2.0", only: :test},
      {:mongodb_driver, "~> 0.9.1"},
      private_git(
        name: :query_parser,
        host: "github.com",
        project: "lenra-io/query-parser.git",
        tag: "mongo-query",
        credentials: "shiipou:#{System.get_env("GH_PERSONNAL_TOKEN")}"
      ),
      private_git(
        name: :lenra_common,
        host: "github.com",
        project: "lenra-io/lenra-common.git",
        tag: "v2.0.4",
        credentials: "shiipou:#{System.get_env("GH_PERSONNAL_TOKEN")}"
      )
    ]
  end

  defp aliases do
    [
      test: [
        "ecto.drop --repo ApplicationRunner.Repo",
        "ecto.create --quiet",
        "ecto.migrate",
        "test"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end

  defp private_git(opts) do
    name = Keyword.fetch!(opts, :name)
    host = Keyword.fetch!(opts, :host)
    project = Keyword.fetch!(opts, :project)
    tag = Keyword.fetch!(opts, :tag)
    credentials = Keyword.get(opts, :credentials)

    case System.get_env("CI") do
      "true" ->
        {name, git: "https://#{credentials}@#{host}/#{project}", tag: tag, submodules: true}

      _ ->
        {name, git: "git@#{host}:#{project}", tag: tag, submodules: true}
    end
  end
end
