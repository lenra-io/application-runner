defmodule ApplicationRunner.NotificationsController do
  defmacro __using__(opts) do
    adapter_mod = Keyword.fetch!(opts, :adapter)

    quote do
      use ApplicationRunner, :controller
      alias ApplicationRunner.Notifications
      alias ApplicationRunner.Notifications.Notif

      @adapter_mod unquote(adapter_mod)

      def notify(conn, params) do
        with notif <- Notif.new(params),
             updated_notif <- Notifications.put_uids_to_notif(notif),
             :ok <- @adapter_mod.send_notification(updated_notif) do
          conn
          |> reply(:ok)
        end
      end
    end
  end
end
