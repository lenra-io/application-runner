import Config

config :application_runner,
  additional_app_modules: [ApplicationRunner.MockGenServer],
  additional_session_modules: [ApplicationRunner.MockGenServer]
