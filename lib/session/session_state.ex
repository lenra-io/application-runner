defmodule ApplicationRunner.SessionState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id, :env, :user, :function_name]
  defstruct [
    :session_id,
    :env,
    :user,
    :function_name,
    :session_supervisor_pid,
    :inactivity_timeout,
    :assigns
  ]

  @type t :: %ApplicationRunner.SessionState{
          session_id: integer(),
          env: term(),
          user: term(),
          function_name: String.t(),
          session_supervisor_pid: pid(),
          inactivity_timeout: number(),
          assigns: term()
        }
end
