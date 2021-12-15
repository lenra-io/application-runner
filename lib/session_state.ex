defmodule ApplicationRunner.SessionState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id, :env_id]
  defstruct [
    :session_id,
    :env_id,
    :widgets_map,
    :listeners_map
  ]

  @type t :: %ApplicationRunner.SessionState{
    session_id: integer(),
    env_id: integer(),
    widgets_map: map(),
    listeners_map: map()
  }
end
