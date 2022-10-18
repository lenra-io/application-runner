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
       git: "https://github.com/lenra-io/ex_component_schema", ref: "v1.0.0-beta.3"},
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
      {:crontab, "~> 1.1"},
      {:query_parser, git: "https://github.com/lenra-io/query-parser.git", tag: "v1.0.0-beta.15"},
      {:lenra_common, git: "https://github.com/lenra-io/lenra-common.git", tag: "v2.4.0"}
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
      "ecto.migrations": [
        "ecto.migrations --migrations-path priv/repo/migrations --migrations-path priv/repo/test_migrations"
      ],
      "ecto.migrate": [
        "ecto.migrate --migrations-path priv/repo/migrations --migrations-path priv/repo/test_migrations"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
