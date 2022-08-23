defmodule ApplicationRunner.AppChannel do
  @moduledoc """
    `ApplicationRunner.AppChannel` handle the app channel to run app and listeners and push to the user the resulted UI or Patch
  """

  defmacro __using__(_opts) do
    quote do
      use Phoenix.Channel

      alias ApplicationRunner.Environment
      alias ApplicationRunner.Session

      alias LenraCommonWeb.ErrorHelpers

      alias ApplicationRunner.Errors.{BusinessError, TechnicalError}

      require Logger

      def join("app", %{"app" => app_name}, socket) do
        session_id = Ecto.UUID.generate()
        user = socket.assigns.user
        socket = assign(socket, session_id: session_id)

        Logger.debug("Joining channel for app : #{app_name}")

        with {:ok, _uuid} <- Ecto.UUID.cast(app_name),
             function_name <- get_function_name(app_name),
             :ok <- allow(user.id, app_name),
             env_id <- get_env(app_name),
             {:ok, session_token} <- create_session_token(env_id, session_id, user.id),
             {:ok, env_token} <- create_env_token(env_id) do
          # prepare the assigns to the session/environment
          session_metadaata = %Session.Metadata{
            env_id: env_id,
            session_id: session_id,
            user_id: user.id,
            function_name: function_name,
            socket_pid: self(),
            token: session_token
          }

          env_metdata = %Environment.Metadata{
            env_id: env_id,
            function_name: function_name,
            token: env_token
          }

          case Session.start_session(
                 session_metadaata,
                 env_metdata
               ) do
            {:ok, session_pid} ->
              {:ok, assign(socket, session_pid: session_pid)}

            # Application error
            {:error, reason} when is_bitstring(reason) ->
              {:error, %{message: reason, reason: "application_error"}}

            {:error, reason} when is_struct(reason) ->
              {:error, %{error: ErrorHelpers.translate_error(reason)}}
          end
        else
          {:error, :forbidden} ->
            {:error, ErrorHelpers.translate_error(BusinessError.no_app_found())}

          err ->
            BusinessError.no_app_found_tuple()
        end
      end

      def join("app", _any, _socket) do
        BusinessError.no_app_found_tuple()
      end

      # Override this function to allow user or not according to the server/devtools needs
      defp allow(user_id, app_name) do
        false
      end

      # Override this function to return the function name according to the server/devtools needs
      @spec get_function_name(String.t()) :: String.t()
      defp get_function_name(app_name) do
        String.downcase("dev-#{app_name}-1")
      end

      # Override this function to return the function name according to the server/devtools needs
      defp get_env(app_name) do
        1
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

        push(socket, "error", %{"errors" => formatted_errors})
        {:noreply, socket}
      end

      def handle_info({:send, :error, malformatted_error}, socket) do
        Logger.error("Malformatted error #{inspect(malformatted_error)}")

        push(socket, "error", %{
          "errors" => ErrorHelpers.translate_error(TechnicalError.unknown_error())
        })

        {:noreply, socket}
      end

      ######
      # IN #
      ######

      def handle_in("run", %{"code" => code, "event" => event}, socket) do
        ApplicationRunner.AppChannel.handle_run(socket, code, event)
      end

      def handle_in("run", %{"code" => code}, socket) do
        ApplicationRunner.AppChannel.handle_run(socket, code)
      end

      defoverridable allow: 2, get_function_name: 1, get_env: 1
    end
  end

  alias ApplicationRunner.Guardian.AppGuardian
  alias ApplicationRunner.Session
  require Logger

  def handle_run(socket, code, event \\ %{}) do
    %{
      session_pid: session_pid
    } = socket.assigns

    Logger.debug("Handle run #{code}")
    Session.send_client_event(session_pid, code, event)

    {:noreply, socket}
  end

  def create_env_token(env_id) do
    with {:ok, token, _claims} <-
           AppGuardian.encode_and_sign(env_id, %{type: "env", env_id: env_id}) do
      {:ok, token}
    end
  end

  def create_session_token(env_id, session_id, user_id) do
    with {:ok, token, _claims} <-
           AppGuardian.encode_and_sign(session_id, %{
             type: "session",
             user_id: user_id,
             env_id: env_id
           }) do
      {:ok, token}
    end
  end
end
