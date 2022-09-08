defmodule ApplicationRunner.Router do
  defmacro app_routes do
    quote do
      alias ApplicationRunner.Guardian.EnsureAuthenticatedAppPipeline

      pipeline :ensure_auth_app do
        plug(EnsureAuthenticatedAppPipeline)
      end

      scope "/app", ApplicationRunner do
        pipe_through([:api, :ensure_auth_app])

        delete("/colls/:coll", CollsController, :delete)
        get("/colls/:coll/docs", DocsController, :get_all)
        post("/colls/:coll/docs", DocsController, :create)
        get("/colls/:coll/docs/:docId", DocsController, :get)
        put("/colls/:coll/docs/:docId", DocsController, :update)
        delete("/colls/:coll/docs/:docId", DocsController, :delete)
        post("/colls/:coll/docs/filter", DocsController, :filter)
      end
    end
  end
end
