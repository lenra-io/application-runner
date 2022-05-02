import Config

# Configure JSON validator
config :ex_component_schema,
       :remote_schema_resolver,
       {ApplicationRunner.JsonSchemata, :read_schema}

config :application_runner,
  adapter: ApplicationRunner.ApplicationRunnerAdapter,
  # 10 min
  session_inactivity_timeout: 1000 * 60 * 10,
  # 60 min
  env_inactivity_timeout: 1000 * 60 * 60,
  lenra_environment_schema: ApplicationRunner.FakeLenraEnvironment,
  lenra_user_schema: ApplicationRunner.FakeLenraUser

config :application_runner, ApplicationRunner.Repo,
  database: "file::memory:?cache=shared",
  log: false

config :swarm,
  debug: false

config :logger,
  level: :warning

import_config "#{Mix.env()}.exs"
