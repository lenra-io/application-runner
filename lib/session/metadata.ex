defmodule ApplicationRunner.Session.Metadata do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id, :env_id, :user_id, :function_name, :token]
  defstruct [
    :env_id,
    :session_id,
    :user_id,
    :function_name,
    :token,
    :session_supervisor_pid
  ]

  @type t :: %__MODULE__{
          env_id: term(),
          session_id: integer(),
          user_id: term(),
          function_name: String.t(),
          token: String.t(),
          session_supervisor_pid: pid()
        }
end
