defmodule ApplicationRunner.CollsController do
  use ApplicationRunner, :controller

  alias ApplicationRunner.MongoStorage
  alias ApplicationRunner.Errors.BusinessError

  def delete(conn, %{"coll" => coll}) do
    with %{environment: env} <- Guardian.Plug.current_resource(conn),
         :ok <- MongoStorage.delete_coll(env.id, coll) do
      reply(conn)
    end
  end

  def delete(_conn, _params) do
    BusinessError.invalid_route_tuple()
  end
end
