defmodule ApplicationRunner.Session.Task.OnSessionStart do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  alias ApplicationRunner.ApplicationServices

  @on_session_start_action "onSessionStart"

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(state) do
    ApplicationServices.run_listener(state, @on_session_start_action, %{}, %{})
  end
end
