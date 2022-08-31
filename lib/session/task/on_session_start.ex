defmodule ApplicationRunner.Session.Task.OnSessionStart do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  @on_session_start_action "onSessionStart"

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    ApplicationRunner.EventHandler.send_session_event(
      session_id,
      @on_session_start_action,
      %{},
      %{}
    )

    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    :ok
  end
end
