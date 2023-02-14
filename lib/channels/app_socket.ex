defmodule ApplicationRunner.AppSocket do
  defmacro __using__(opts) do
    route_channel = Keyword.fetch!(opts, :route_channel)
    routes_channel = Keyword.fetch!(opts, :routes_channel)
    adapter_mod = Keyword.fetch!(opts, :adapter)

    quote do
      require Logger
      use Phoenix.Socket

      alias ApplicationRunner.AppSocket
      alias ApplicationRunner.Contract.User
      alias ApplicationRunner.Environment
      alias ApplicationRunner.Errors.{BusinessError, TechnicalError}
      alias ApplicationRunner.Monitor
      alias ApplicationRunner.Session
      alias ApplicationRunner.Telemetry
      alias LenraCommonWeb.ErrorHelpers

      @adapter_mod unquote(adapter_mod)

      defoverridable init: 1

      ## Channels
      channel("route:*", unquote(route_channel))
      channel("routes", unquote(routes_channel))

      @impl true
      def init(state) do
        res = {:ok, {_, socket}} = super(state)

        Monitor.SessionMonitor.monitor(self(), socket.assigns)
        res
      end

      # Socket params are passed from the client and can
      # be used to verify and authenticate a user. After
      # verification, you can put default assigns into
      # the socket that will be set for all channels, ie
      #
      #     {:ok, assign(socket, :user_id, verified_user_id)}
      #
      # To deny connection, return `:error`.
      #
      # See `Phoenix.Token` documentation for examples in
      # performing token verification on connect.
      @impl true
      def connect(params, socket, _connect_info) do
        with {:ok, app_name, context} <- extract_params(params),
             {:ok, user_id} <- @adapter_mod.resource_from_params(params),
             :ok <- @adapter_mod.allow(user_id, app_name),
             {:ok, env_metadata, session_metadata} <-
               create_metadatas(user_id, app_name, context),
             start_time <- Telemetry.start(:app_session, session_metadata),
             {:ok, session_pid} <- Session.start_session(session_metadata, env_metadata) do
          Logger.notice("Joined app #{app_name} with params #{inspect(params)}")

          Logger.debug(
            "#{app_name}: /n/t session_metadata: #{inspect(session_metadata)} /n/t env_metadata: #{inspect(env_metadata)}"
          )

          socket =
            socket
            |> assign(env_id: session_metadata.env_id)
            |> assign(session_id: session_metadata.session_id)
            |> assign(user_id: user_id)
            |> assign(start_time: start_time)

          {:ok, socket}
        else
          {:error, reason} when is_bitstring(reason) ->
            Logger.warning(%{message: reason, reason: "application_error"})
            {:error, %{message: reason, reason: "application_error"}}

          {:error, reason} when is_struct(reason) ->
            Logger.error(reason)
            {:error, ErrorHelpers.translate_error(reason)}

          {:error, reason} ->
            Logger.error(reason)
            {:error, ErrorHelpers.translate_error(TechnicalError.unknown_error())}
        end
      end

      defp extract_params(params) do
        app_name = Map.get(params, "app")
        context = Map.get(params, "context", %{})

        if is_nil(app_name) do
          BusinessError.no_app_found_tuple()
        else
          {:ok, app_name, context}
        end
      end

      defp create_metadatas(user_id, app_name, context) do
        session_id = Ecto.UUID.generate()

        with function_name when is_bitstring(function_name) <-
               @adapter_mod.get_function_name(app_name),
             env_id <- @adapter_mod.get_env_id(app_name),
             {:ok, session_token} <- create_session_token(env_id, session_id, user_id),
             {:ok, env_token} <- create_env_token(env_id) do
          # prepare the assigns to the session/environment
          session_metadata = %Session.Metadata{
            env_id: env_id,
            session_id: session_id,
            user_id: user_id,
            function_name: function_name,
            context: context,
            token: session_token
          }

          env_metadata = %Environment.Metadata{
            env_id: env_id,
            function_name: function_name,
            token: env_token
          }

          {:ok, env_metadata, session_metadata}
        else
          {:error, :forbidden} ->
            {:error, BusinessError.forbidden()}

          err ->
            err
        end
      end

      def create_env_token(env_id) do
        AppSocket.do_create_env_token(env_id)
      end

      def create_session_token(env_id, session_id, user_id) do
        AppSocket.do_create_session_token(env_id, session_id, user_id)
      end

      # Socket id's are topics that allow you to identify all sockets for a given user:
      #
      #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
      #
      # Would allow you to broadcast a "disconnect" event and terminate
      # all active sockets and channels for a given user:
      #
      #     LenraWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
      #
      # Returning `nil` makes this socket anonymous.
      @impl true
      def id(socket), do: "app_socket:#{socket.assigns.user_id}"
    end
  end

  alias ApplicationRunner.Guardian.AppGuardian

  def do_create_env_token(env_id) do
    with {:ok, token, _claims} <-
           AppGuardian.encode_and_sign(env_id, %{type: "env", env_id: env_id}) do
      {:ok, token}
    end
  end

  def do_create_session_token(env_id, session_id, user_id) do
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
