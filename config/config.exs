import Config

config :phoenix, :json_library, Jason

# Configure JSON validator
config :ex_component_schema,
       :remote_schema_resolver,
       {ApplicationRunner.JsonSchemata, :read_schema}

config :application_runner,
  # 10 min
  session_inactivity_timeout: 1000 * 60 * 10,
  # 60 min
  env_inactivity_timeout: 1000 * 60 * 60,
  # 10 min
  query_inactivity_timeout: 1000 * 60 * 10,
  # 1 hour
  listeners_timeout: 1 * 60 * 60 * 1000,
  # 30 s
  view_timeout: 1 * 30 * 1000,
  manifest_timeout: 1 * 30 * 1000,
  lenra_environment_table: "environments",
  lenra_user_table: "users",
  repo: ApplicationRunner.Repo,
  url: "localhost:4000",
  env: "dev"

config :application_runner, :mongo,
  hostname: "localhost",
  port: "27017",
  ssl: false

config :application_runner, ApplicationRunner.Repo,
  database: "file::memory:?cache=shared",
  log: false

config :swarm,
  debug: false

config :logger,
  level: :warning

import_config "#{Mix.env()}.exs"
