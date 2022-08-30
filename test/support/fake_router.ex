defmodule ApplicationRunner.FakeRouter do
  @moduledoc """
    This is a stub router for unit test only.
  """
  use ApplicationRunner, :router

  require ApplicationRunner.Router

  ApplicationRunner.Router.app_routes()

  pipeline :api do
    plug(:accepts, ["json"])
  end
end
