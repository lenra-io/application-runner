import Config

config :application_runner,
  additional_env_modules: [ApplicationRunner.MockGenServer],
  additional_session_modules: [ApplicationRunner.MockGenServer],
  lenra_environment_schema: ApplicationRunner.FakeLenraEnvironment,
  lenra_user_schema: ApplicationRunner.FakeLenraUser,
  ecto_repos: [ApplicationRunner.Repo]
