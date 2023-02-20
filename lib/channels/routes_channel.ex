defmodule ApplicationRunner.RoutesChannel do
  @moduledoc """
    `ApplicationRunner.RoutesChannel` handles the app channel to run app and listeners and push to the user the resulted UI or Patch
  """
  use SwarmNamed

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Channel

      alias ApplicationRunner.Environment
      alias ApplicationRunner.Guardian.AppGuardian
      alias ApplicationRunner.Session

      alias LenraCommonWeb.ErrorHelpers

      alias ApplicationRunner.Errors.{BusinessError, DevError, TechnicalError}

      require Logger

      def join("routes", %{"mode" => "lenra"}, socket) do
        env_id = socket.assigns.env_id
        manifest = Environment.ManifestHandler.get_manifest(env_id)
        session_id = socket.assigns.session_id

        res = %{"lenraRoutes" => Map.get(manifest, "lenraRoutes")}

        with :yes <- Swarm.register_name(get_swarm_name(session_id), self()) do
          {:ok, res, socket}
        else
          :no ->
            Logger.critical(
              BusinessError.could_not_register_appchannel(%{
                session_id: session_id,
                route: "routes"
              })
            )

            {:error, DevError.message("Could not register the AppChannel into swarm")}

          err ->
            err
        end
      end

      def join("routes", %{"mode" => "json"}, socket) do
        env_id = socket.assigns.env_id
        manifest = Environment.ManifestHandler.get_manifest(env_id)

        res = %{"jsonRoutes" => Map.get(manifest, "jsonRoutes")}

        {:ok, res, socket}
      end

      def join(_, _any, _socket) do
        {:error, ErrorHelpers.translate_error(BusinessError.invalid_channel_name())}
      end

      ########
      # INFO #
      ########

      # Send new route to client
      def handle_info({:send, :navTo, route}, socket) do
        Logger.debug("send route #{inspect(route)}")
        push(socket, "navTo", route)
        {:noreply, socket}
      end

      def get_swarm_name(session_id) do
        ApplicationRunner.RoutesChannel.get_name(session_id)
      end
    end
  end
end
