defmodule ApplicationRunner.Session.Task.OnUserFirstJoin do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  alias ApplicationRunner.{ApplicationServices, MongoStorage}

  @on_user_first_join_action "onUserFirstJoin"

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    user_id = Keyword.fetch!(opts, :user_id)
    token = Keyword.fetch!(opts, :token)
    function_name = Keyword.fetch!(opts, :function_name)

    Task.start_link(__MODULE__, :run, [env_id, user_id, token, function_name])
  end

  def run(env_id, user_id, token, function_name) do
    if MongoStorage.has_user_link?(env_id, user_id) do
      :ok
    else
      MongoStorage.create_user_link(%{environment_id: env_id, user_id: user_id})

      ApplicationServices.run_listener(
        function_name,
        @on_user_first_join_action,
        %{},
        %{},
        token
      )
    end
  end
end
