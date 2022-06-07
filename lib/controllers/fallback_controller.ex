defmodule ApplicationRunner.FallbackController do
  use ApplicationRunner, :controller

  def call(conn, {:error, reason}) do
    conn
    |> assign_error(reason)
    |> reply
  end

  def call(conn, {:error, _error, reason, _reason}) do
    conn
    |> assign_error(reason)
    |> reply
  end
end
