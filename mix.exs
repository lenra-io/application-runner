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
       git: "https://github.com/lenra-io/ex_component_schema", ref: "v1.0.0-beta.2"},
      {:jason, "~> 1.2"},
      {:json_diff, "~> 0.1"},
      {:swarm, "~> 3.0"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, "~> 0.15.8", only: [:test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: [
        "ecto.drop --repo ApplicationRunner.Repo",
        "ecto.create --quiet",
        "ecto.migrate",
        "test"
      ]
    ]
  end
end
