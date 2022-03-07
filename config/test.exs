import Config

config :application_runner,
  additional_env_modules: [ApplicationRunner.MockGenServer],
  additional_session_modules: [ApplicationRunner.MockGenServer],
  ecto_repos: [ApplicationRunner.Repo]
