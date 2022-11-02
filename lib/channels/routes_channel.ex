# credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks
defmodule ApplicationRunner.RoutesChannel do
  @moduledoc """
    `ApplicationRunner.RouteChannel` handle the app channel to run app and listeners and push to the user the resulted UI or Patch
  """

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

        res = %{"lenraRoutes" => Map.get(manifest, "lenraRoutes")}

        {:ok, res, socket}
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
    end
  end
end
