defmodule ApplicationRunner.SessionState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id, :env_id, :user_id, :function_name]
  defstruct [
    :session_id,
    :env_id,
    :user_id,
    :function_name,
    :session_supervisor_pid,
    :inactivity_timeout,
    :assigns
  ]

  @type t :: %ApplicationRunner.SessionState{
          session_id: integer(),
          env_id: term(),
          user_id: term(),
          function_name: String.t(),
          session_supervisor_pid: pid(),
          inactivity_timeout: number(),
          assigns: term()
        }
end
