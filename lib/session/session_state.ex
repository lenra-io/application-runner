defmodule ApplicationRunner.SessionState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id, :env_id]
  defstruct [
    :session_id,
    :env_id,
    :session_supervisor_pid,
    :inactivity_timeout,
    :assigns
  ]

  @type t :: %ApplicationRunner.SessionState{
          session_id: integer(),
          env_id: integer(),
          session_supervisor_pid: pid(),
          inactivity_timeout: number(),
          assigns: term()
        }
end
