defmodule ApplicationRunner.Session.Metadata do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id, :env_id, :user_id, :function_name, :token, :context]
  defstruct [
    :env_id,
    :session_id,
    :user_id,
    :function_name,
    :token,
    :context,
    :session_supervisor_pid
  ]

  @type t :: %__MODULE__{
          env_id: term(),
          session_id: integer(),
          user_id: term(),
          function_name: String.t(),
          token: String.t(),
          context: map(),
          session_supervisor_pid: pid()
        }
end
