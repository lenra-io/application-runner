defmodule ApplicationRunner.Ui.Context do
  @moduledoc """
    The UI Context that contain all widgets and listeners information
  """

  defstruct [
    :widgets_map,
    :listeners_map
  ]

  @type t :: %__MODULE__{
          widgets_map: map(),
          listeners_map: map()
        }

  def new() do
    %__MODULE__{widgets_map: %{}, listeners_map: %{}}
  end
end
