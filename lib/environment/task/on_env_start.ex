defmodule ApplicationRunner.Environment.Task.OnEnvStart do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  alias ApplicationRunner.ApplicationServices

  @on_env_start_action "onEnvStart"

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(state) do
    ApplicationServices.run_listener(state, @on_env_start_action, %{}, %{})
  end
end
