import Config

# Configure JSON validator
config :ex_component_schema,
       :remote_schema_resolver,
       {ApplicationRunner.JsonSchemata, :read_schema}

config :application_runner,
  # 10 min
  session_inactivity_timeout: 1000 * 60 * 10,
  # 60 min
  env_inactivity_timeout: 1000 * 60 * 60,
  lenra_environment_table: "environments",
  lenra_user_table: "users",
  repo: ApplicationRunner.Repo,
  url: "localhost:4000",
  faas_url: "http://localhost:1234",
  faas_auth: "Basic YWRtaW46M2kwREc4NTdLWlVaODQ3R0pheW5qMXAwbQ==",
  faas_registry: "registry.gitlab.com/lenra/platform/lenra-ci",
  gitlab_api_url: "http://localhost:4567"

config :application_runner, ApplicationRunner.Repo,
  database: "file::memory:?cache=shared",
  log: false

# Configure Guardian
config :application_runner, ApplicationRunner.Guardian.AppGuardian,
  issuer: "application_runner",
  secret_key: "5oIBVh2Hauo3LT4knNFu29lX9DYu74SWZfjZzYn+gfr0aryxuYIdpjm8xd0qGGqK"

config :swarm,
  debug: false

config :logger,
  level: :warning

import_config "#{Mix.env()}.exs"
