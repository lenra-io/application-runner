defmodule ApplicationRunner.Environment.Task.OnEnvStart do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  @on_env_start_action "onEnvStart"

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    ApplicationRunner.EventHandler.send_env_event(env_id, @on_env_start_action, %{}, %{})
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    :ok
  end
end
