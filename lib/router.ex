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
        post("/colls/:coll/docs/find", DocsController, :find)

        # TODO Add cron routes here

        post("/webhooks", Webhooks.WebhooksController, :create)
      end

      scope "/", ApplicationRunner do
        pipe_through([:api])
        post("/webhooks/:webhook_uuid", Webhooks.WebhooksController, :trigger)
      end

      scope "/api", ApplicationRunner do
        # TODO: How to handle permissions now that we moved this from server to here ?
        pipe_through([:api])

        get("/apps/:app_id/environments/:env_id/crons", CronController, :all)
        get("/apps/:app_id/environments/:env_id/crons/:id", CronController, :get)
        post("/apps/:app_id/environments/:env_id/crons", CronController, :create)
      end
    end
  end

  defmacro resource_route(resource_controller) do
    quote do
      get(
        "/apps/:app_name/resources/:resource",
        unquote(resource_controller),
        :get_app_resource
      )
    end
  end
end
