defmodule ApplicationRunner.WidgetContext do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:widget_name, :prefix_path]
  defstruct [
    :widget_name,
    :data_query,
    :props,
    :prefix_path
  ]

  @type t :: %ApplicationRunner.WidgetContext{
    widget_name: String.t(),
    data_query: map() | nil,
    props: map() | nil,
    prefix_path: String.t()
  }
end
