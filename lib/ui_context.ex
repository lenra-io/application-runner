defmodule ApplicationRunner.UiContext do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:session_id]
  defstruct [
    :session_id,
    :widgets_map,
    :listeners_map
  ]

  @type t :: %ApplicationRunner.UiContext{
    session_id: integer(),
    widgets_map: map(),
    listeners_map: map()
  }
end
