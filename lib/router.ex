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
        delete("/datastores/:datastore", DatastoreController, :delete)
        get("/datastores/user/data/@me", DataController, :get_current_user_data)
        get("/datastores/:datastore/data/:id", DataController, :get)
        get("/datastores/:datastore/data", DataController, :get_all)
        post("/datastores/:datastore/data", DataController, :create)
        delete("/datastores/:datastore/data/:id", DataController, :delete)
        put("/datastores/:datastore/data/:id", DataController, :update)
        post("/query", DataController, :query)
      end
    end
  end
end
