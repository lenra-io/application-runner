defmodule ApplicationRunner.SessionState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id, :env_id]
  defstruct [
    :session_id,
    :env_id
  ]

  @type t :: %ApplicationRunner.SessionState{
          session_id: integer(),
          env_id: integer()
        }
end
