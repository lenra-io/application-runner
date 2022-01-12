defmodule ApplicationRunner.UiContext do
  @moduledoc """
    The UI Context that contain all widgets and listeners information
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
