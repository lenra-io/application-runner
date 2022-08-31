defmodule ApplicationRunner.Session.Task.OnSessionStart do
  @moduledoc """
    OnEnvStart task send listeners onEnvStart
  """

  use Task

  alias ApplicationRunner.ApplicationServices

  @on_session_start_action "onSessionStart"

  def start_link(opts) do
    token = Keyword.fetch!(opts, :token)
    function_name = Keyword.fetch!(opts, :function_name)

    Task.start_link(__MODULE__, :run, [token, function_name])
  end

  def run(token, function_name) do
    ApplicationServices.run_listener(function_name, @on_session_start_action, %{}, %{}, token)
  end
end
