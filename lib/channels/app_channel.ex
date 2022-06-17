defmodule ApplicationRunner.AppChannel do
  @moduledoc """
    `ApplicationRunner.AppChannel` handle the app channel to run app and listeners and push to the user the resulted UI or Patch
  """

  defmacro __using__(opts) do
    quote do
      use Phoenix.Channel

      alias ApplicationRunner.{
        Environment,
        EnvState,
        ErrorHelpers,
        SessionManager,
        SessionManagers,
        SessionState,
        SessionStateServices
      }

      require Logger

      def join("app", %{"app" => app_name}, socket) do
        session_id = Ecto.UUID.generate()
        user = socket.assigns.user

        Logger.debug("Joining channel for app : #{app_name}")

        with {:ok, _uuid} <- Ecto.UUID.cast(app_name),
             %{function_name: function_name} <-
               get_function_name(app_name),
             :ok <- allow(user, app_name),
             :ok <-
               Bouncer.allow(unquote(Keyword.get(opts, :allow)), :join_app, user, application) do
          socket = assign(socket, session_id: session_id)

          # prepare the assigns to the session/environment
          session_state = %SessionState{
            user_id: user.id,
            env: environment,
            function_name: function_name,
            assigns: %{
              socket_pid: self()
            },
            session_id: session_id
          }

          env_state = %{
            env: environment,
            function_name: function_name
          }

          case start_session(session_id, environment.id, session_state, env_state) do
            {:ok, session_pid} ->
              {:ok, assign(socket, session_pid: session_pid)}

            # Application error
            {:error, reason} when is_bitstring(reason) ->
              {:error, %{reason: [%{code: -1, message: reason}]}}

            {:error, reason} when is_atom(reason) ->
              {:error, %{reason: ErrorHelpers.translate_error(reason)}}
          end
        else
          {:error, :forbidden} ->
            {:error, %{reason: ErrorHelpers.translate_error(:no_app_authorization)}}

          _err ->
            {:error, %{reason: ErrorHelpers.translate_error(:no_app_found)}}
        end
      end

      def join("app", _any, _socket) do
        {:error, %{reason: ErrorHelpers.translate_error(:no_app_found)}}
      end

      # Override this function to return the function name according to the server/devtools needs
      defp get_function_name(app_name) do
        String.downcase("dev-#{app_name}-1")
      end

      defp start_session(session_id, env_id, session_state, env_state) do
        case SessionManagers.start_session(session_id, env_id, session_state, env_state) do
          {:ok, session_pid} -> {:ok, session_pid}
          {:error, message} -> {:error, message}
        end
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

      def handle_info({:send, :error, {:error, reason}}, socket) when is_atom(reason) do
        Logger.error("Send error #{inspect(reason)}")

        push(socket, "error", %{"errors" => ErrorHelpers.translate_error(reason)})
        {:noreply, socket}
      end

      def handle_info({:send, :error, {:error, :invalid_ui, errors}}, socket)
          when is_list(errors) do
        formatted_errors =
          errors
          |> Enum.map(fn {message, path} -> %{code: 0, message: "#{message} at path #{path}"} end)

        push(socket, "error", %{"errors" => formatted_errors})
        {:noreply, socket}
      end

      def handle_info({:send, :error, reason}, socket) when is_atom(reason) do
        Logger.error("Send error atom #{inspect(reason)}")
        push(socket, "error", %{"errors" => ErrorHelpers.translate_error(reason)})
        {:noreply, socket}
      end

      def handle_info({:send, :error, malformatted_error}, socket) do
        Logger.error("Malformatted error #{inspect(malformatted_error)}")
        push(socket, "error", %{"errors" => ErrorHelpers.translate_error(:unknow_error)})
        {:noreply, socket}
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

      defp handle_run(socket, code, event \\ %{}) do
        %{
          session_pid: session_pid
        } = socket.assigns

        Logger.debug("Handle run #{code}")
        SessionManager.send_client_event(session_pid, code, event)

        {:noreply, socket}
      end
    end
  end
end
