defmodule ApplicationRunner.Session.Events.OnUserFirstJoin do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use GenServer, restart: :transient

  alias ApplicationRunner.MongoStorage

  @on_user_first_join_action "onUserFirstJoin"

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    env_id = Keyword.fetch!(opts, :env_id)
    user_id = Keyword.fetch!(opts, :user_id)

    GenServer.start_link(__MODULE__, [session_id, env_id, user_id])
  end

  def init([session_id, env_id, user_id]) do
    with false <- MongoStorage.has_user_link?(env_id, user_id),
         {:ok, _} <-
           MongoStorage.create_user_link(%{environment_id: env_id, user_id: user_id}),
         :ok <-
           ApplicationRunner.EventHandler.send_session_event(
             session_id,
             @on_user_first_join_action,
             %{},
             %{}
           ) do
      {:ok, :ok, {:continue, :stop_me}}
    else
      true ->
        {:ok, :ok, {:continue, :stop_me}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_continue(:stop_me, state) do
    {:stop, :normal, state}
  end
end
