defmodule ApplicationRunner.WidgetContext do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:widget_id, :widget_name]
  defstruct [
    :widget_id,
    :widget_name,
    :data_query,
    :props,
    :prefix_path
  ]

  @type t :: %ApplicationRunner.WidgetContext{
    widget_id: String.t(),
    widget_name: String.t(),
    data_query: map() | nil,
    props: map() | nil,
    prefix_path: String.t() | nil
  }
end
