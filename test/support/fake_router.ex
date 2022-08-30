defmodule ApplicationRunner.FakeRouter do
  use ApplicationRunner, :router

  require ApplicationRunner.Router

  ApplicationRunner.Router.app_routes()

  pipeline :api do
    plug(:accepts, ["json"])
  end
end
