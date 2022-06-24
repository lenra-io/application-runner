defmodule ApplicationRunner.Router do
  defmacro app_routes do
    quote do
      alias ApplicationRunner.Guardian.EnsureAuthenticatedAppPipeline

      pipeline :ensure_auth_app do
        plug(EnsureAuthenticatedAppPipeline)
      end

      scope "/app", ApplicationRunner do
        pipe_through([:api, :ensure_auth_app])

        post("/datastores", DatastoreController, :create)
        delete("/datastores/:_datastore", DatastoreController, :delete)
        get("/datastores/user/data/@me", DataController, :get_me)
        get("/datastores/:_datastore/data/:_id", DataController, :get)
        get("/datastores/:_datastore/data", DataController, :get_all)
        post("/datastores/:_datastore/data", DataController, :create)
        delete("/datastores/:_datastore/data/:_id", DataController, :delete)
        put("/datastores/:_datastore/data/:_id", DataController, :update)
        post("/query", DataController, :query)
      end
    end
  end
end
