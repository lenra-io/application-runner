defmodule ApplicationRunner.Session.Task.OnUserFirstJoin do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  alias ApplicationRunner.{ApplicationServices, Session, MongoStorage}

  @on_user_first_join_action "onUserFirstJoin"

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    env_metadata = Session.MetadataAgent.get_metadata(session_id)

    Task.start_link(__MODULE__, :run, [env_metadata.env_id, env_metadata.user_id])
  end

  def run(session_id, env_id, user_id) do
    if MongoStorage.has_user_link?(env_id, user_id) do
      :ok
    else
      with {:ok, _} <- MongoStorage.create_user_link(%{environment_id: env_id, user_id: user_id}) do
        ApplicationRunner.EventHandler.send_session_event(
          session_id,
          @on_user_first_join_action,
          %{},
          %{}
        )
      end
    end
  end
end
