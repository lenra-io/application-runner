import Config

config :lenra, Mongo.Repo,
  username: System.fetch_env!("MONGO_USERNAME"),
  password: System.fetch_env!("MONGO_PASSWORD"),
  hostname: System.fetch_env!("MONGO_HOST")

config :application_runner,
  env: Application.fetch_env!("ENV")
