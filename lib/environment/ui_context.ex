defmodule ApplicationRunner.UiContext do
  @moduledoc """
    The Action struct.
  """

  defstruct [
    :widgets_map,
    :listeners_map
  ]

  @type t :: %ApplicationRunner.UiContext{
          widgets_map: map(),
          listeners_map: map()
        }
end
