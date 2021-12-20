defmodule ApplicationRunner.WidgetContext do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:id, :name]
  defstruct [
    :id,
    :name,
    :data_query,
    :props,
    :prefix_path
  ]

  @type t :: %ApplicationRunner.WidgetContext{
          id: String.t(),
          name: String.t(),
          data_query: map() | nil,
          props: map() | nil,
          prefix_path: String.t() | nil
        }
end
