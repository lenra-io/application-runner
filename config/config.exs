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
  app_inactivity_timeout: 1000 * 60 * 60,
  additional_app_modules: [],
  additional_session_modules: []

import_config "#{Mix.env()}.exs"
