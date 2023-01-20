# credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks
defmodule ApplicationRunner.RouteChannel do
  @moduledoc """
    `ApplicationRunner.RouteChannel` handle the app channel to run app and listeners and push to the user the resulted UI or Patch
  """

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Channel
      use SwarmNamed

      alias ApplicationRunner.Environment
      alias ApplicationRunner.Guardian.AppGuardian
      alias ApplicationRunner.Session

      alias LenraCommonWeb.ErrorHelpers

      alias ApplicationRunner.Errors.{BusinessError, TechnicalError}
      alias LenraCommon.Errors.DevError

      require Logger

      def join("route:" <> route, params, socket) do
        mode = Map.get(params, "mode", "lenra")
        session_id = socket.assigns.session_id
        Logger.debug("Join for #{session_id}, with params: #{params}")

        with sm <- Session.MetadataAgent.get_metadata(session_id),
             :yes <- Swarm.register_name(get_name({session_id, mode, route}), self()),
             :ok <- Swarm.join(get_group(session_id, mode, route), self()),
             {:ok, _pid} <-
               Session.RouteDynSup.ensure_child_started(sm.env_id, session_id, mode, route) do
          Logger.notice("Route #{route}, in mode #{mode}, open for session: #{session_id}")
          {:ok, socket}
        else
          :no ->
            Logger.critical(
              "Could not register the AppChannel into swarm, session_id: #{session_id}, route #{route}"
            )

            {:error, DevError.message("Could not register the AppChannel into swarm")}

          err ->
            err
        end
      end

      def join(_, _any, _socket) do
        Logger.critical(BusinessError.invalid_channel_name())
        {:error, ErrorHelpers.translate_error(BusinessError.invalid_channel_name())}
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

      ########
      # INFO #
      ########
      def handle_info({:send, :ui, ui}, socket) do
        Logger.debug("send ui #{inspect(ui)}")
        push(socket, "ui", ui)
        {:noreply, socket}
      end

      def handle_info({:send, :patches, patches}, socket) do
        Logger.debug("send patchUi  #{inspect(%{patch: patches})}")

        push(socket, "patchUi", %{"patch" => patches})
        {:noreply, socket}
      end

      def handle_info({:send, :error, {:error, err}}, socket) when is_struct(err) do
        Logger.error("Send error #{inspect(err)}")

        push(socket, "error", ErrorHelpers.translate_error(err))
        {:noreply, socket}
      end

      def handle_info({:send, :error, {:error, :invalid_ui, errors}}, socket)
          when is_list(errors) do
        formatted_errors =
          errors
          |> Enum.map(fn {message, path} ->
            %{message: "#{message} at path #{path}", reason: "invalid_ui"}
          end)

        Logger.notice("Channel error: #{formatted_errors}")

        push(socket, "error", %{"errors" => formatted_errors})
        {:noreply, socket}
      end

      def handle_info({:send, :error, malformatted_error}, socket) do
        Logger.critical("Malformatted error #{inspect(malformatted_error)}")

        push(socket, "error", %{
          "errors" => ErrorHelpers.translate_error(TechnicalError.unknown_error())
        })

        {:noreply, socket}
      end

      def get_group(session_id, mode, route) do
        ApplicationRunner.RouteChannel.get_group(session_id, mode, route)
      end
    end
  end

  def get_group(session_id, mode, route) do
    {__MODULE__, session_id, mode, route}
  end
end
