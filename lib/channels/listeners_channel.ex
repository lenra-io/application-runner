# credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks
defmodule ApplicationRunner.ListenersChannel do
  @moduledoc """
    `ApplicationRunner.AppChannel` handle the app channel to run app and listeners and push to the user the resulted UI or Patch
  """

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Channel

      alias ApplicationRunner.Environment
      alias ApplicationRunner.Guardian.AppGuardian
      alias ApplicationRunner.Session

      alias LenraCommonWeb.ErrorHelpers

      alias ApplicationRunner.Errors.{BusinessError, TechnicalError}
      alias LenraCommon.Errors.DevError

      require Logger

      def join("listeners", _params, socket) do
        {:ok, socket}
      end

      ######
      # IN #
      ######

      def handle_in("run", %{"code" => code, "event" => event}, socket) do
        handle_run(socket, code, event)
      end

      def handle_in("run", %{"code" => code}, socket) do
        handle_run(socket, code)
      end

      def handle_run(socket, code, event \\ %{}) do
        session_id = Map.fetch!(socket.assigns, :session_id)

        Logger.debug("Handle run #{code}")

        case Session.send_client_event(session_id, code, event) do
          {:error, err} ->
            Phoenix.Channel.push(socket, "error", ErrorHelpers.translate_error(err))
            {:reply, {:error, %{"error" => err}}, socket}

          _ ->
            {:reply, {:ok, %{}}, socket}
        end

        {:noreply, socket}
      end
    end
  end
end
