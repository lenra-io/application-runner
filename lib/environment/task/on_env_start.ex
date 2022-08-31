defmodule ApplicationRunner.Environment.Task.OnEnvStart do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  @on_env_start_action "onEnvStart"

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    Task.start_link(__MODULE__, :run, [env_id])
  end

  def run(env_id) do
    ApplicationRunner.EventHandler.send_env_event(env_id, @on_env_start_action, %{}, %{})
  end
end
