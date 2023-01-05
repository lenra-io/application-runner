defmodule ApplicationRunner.CollsController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.Environment.MongoInstance
  alias ApplicationRunner.MongoStorage

  def delete(conn, %{"coll" => coll}) do
    with %{environment: env} <- Guardian.Plug.current_resource(conn),
         :ok <- MongoInstance.run_mongo_task(env.id, MongoStorage, :delete_coll, [env.id, coll]) do
      reply(conn)
    end
  end
end
