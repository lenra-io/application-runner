defmodule ApplicationRunner.MixProject do
  use Mix.Project

  def project do
    [
      app: :application_runner,
      version: "",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ApplicationRunner.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_json_schema, "~> 0.7.4"},
      {:jason, "~> 1.2"},
      {:json_diff, "~> 0.1"}
    ]
  end
end
