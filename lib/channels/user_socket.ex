defmodule ApplicationRunner.UserSocket do
  defmacro __using__(opts) do
    channel = Keyword.fetch!(opts, :channel)

    quote do
      use Phoenix.Socket

      alias ApplicationRunner.User

      @repo Application.compile_env(:application_runner, :repo)

      ## Channels
      channel("app", unquote(channel))

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
        case resource_from_params(params) do
          {:ok, user_id} ->
            {:ok, assign(socket, :user, @repo.get(User, user_id))}

          err ->
            Logger.error(err)
            :error
        end
      end

      # Override this function to return the ressource according to the server/devtools needs
      defp resource_from_params(_params) do
        :error
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
      def id(socket), do: "user_socket:#{socket.assigns.user.id}"

      defoverridable resource_from_params: 1
    end
  end
end
