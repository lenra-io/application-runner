defmodule ApplicationRunner.WidgetContext do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:id, :name, :prefix_path]
  defstruct [
    :id,
    :name,
    :data,
    :props,
    :prefix_path
  ]

  @type t :: %ApplicationRunner.WidgetContext{
          id: String.t(),
          name: String.t(),
          data: map() | nil,
          props: map() | nil,
          prefix_path: String.t() | nil
        }
end
