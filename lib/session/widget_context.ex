defmodule ApplicationRunner.WidgetContext do
  @moduledoc """
    The Widget context struct from the developer application.
  """
  @enforce_keys [:id, :name, :prefix_path]
  defstruct [
    :id,
    :name,
    :data,
    :query,
    :props,
    :prefix_path
  ]

  @type t :: %ApplicationRunner.WidgetContext{
          id: String.t(),
          name: String.t(),
          data: list(map()) | map() | nil,
          query: map() | nil,
          props: map() | nil,
          prefix_path: String.t() | nil
        }
end
