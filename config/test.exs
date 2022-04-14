import Config

config :application_runner,
  additional_env_modules: fn _ -> [ApplicationRunner.MockGenServer] end,
  additional_session_modules: fn _ -> [ApplicationRunner.MockGenServer] end,
  ecto_repos: [ApplicationRunner.Repo]

config :application_runner, ApplicationRunner.Repo,
  username: "postgres",
  password: "postgres",
  database: "applicationrunner_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  pool: Ecto.Adapters.SQL.Sandbox

config :swarm,
  sync_nodes_timeout: 0
