import Config

# Configure JSON validator
config :ex_json_schema,
       :remote_schema_resolver,
       {ApplicationRunner.JsonSchemata, :read_schema}

config :application_runner,
  adapter: ApplicationRunner.ApplicationRunnerAdapter