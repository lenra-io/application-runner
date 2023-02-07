defmodule ApplicationRunner.NotificationsController do
  defmacro __using__(opts) do
    adapter_mod = Keyword.fetch!(opts, :adapter)

    quote do
      use ApplicationRunner, :controller
      alias ApplicationRunner.Notifications
      alias ApplicationRunner.Notifications.Notif
      alias ApplicationRunner.Guardian.AppGuardian

      @adapter_mod unquote(adapter_mod)

      def notify(conn, params) do
        with resources <- get_resource!(conn),
             mongo_user_id <- get_mongo_user_id(resources),
             notif <- Notif.new(params),
             updated_notif <- Notifications.put_uids_to_notif(notif, mongo_user_id),
             :ok <- @adapter_mod.send_notification(updated_notif) do
          conn
          |> reply(:ok)
        end
      end

      defp get_resource!(conn) do
        case AppGuardian.Plug.current_resource(conn) do
          nil -> raise DevError.exception(message: "There is no resource loaded from token.")
          res -> res
        end
      end

      defp get_mongo_user_id(%{mongo_user_link: mongo_user_link}) do
        mongo_user_link.mongo_user_id
      end
    end
  end
end
