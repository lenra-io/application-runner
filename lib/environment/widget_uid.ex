defmodule ApplicationRunner.Environment.WidgetUid do
  @moduledoc """
    This identify a unique widget for a given environment.
  """
  @enforce_keys [:name, :coll, :query, :props]
  defstruct [
    :name,
    :props,
    :query,
    :coll
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          props: map() | nil,
          query: String.t(),
          coll: String.t()
        }
end
