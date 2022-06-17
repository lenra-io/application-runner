defmodule ApplicationRunner.UserSocket do
  defmacro __using__(opts) do
    quote do
      use Phoenix.Socket

      ## Channels
      channel("app", unquote(Keyword.get(opts, :channel)))

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
      def connect(%{"token" => token}, socket, _connect_info) do
        case resource_from_token(token) do
          {:ok, user, _claims} -> {:ok, assign(socket, :user, user)}
          _error -> :error
        end
      end

      def connect(_params, _socket, _connect_info) do
        :error
      end

      # Override this function to return the ressource according to the server/devtools needs
      defp resource_from_token(_token) do
        %{}
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
    end
  end
end
