defmodule ApplicationRunner.Widget.Context do
  @moduledoc """
    The Widget context struct from the developer application.
  """
  @enforce_keys [:id, :name, :prefix_path]
  defstruct [
    :id,
    :name,
    :data,
    :props,
    :prefix_path
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          data: list(map()) | map() | nil,
          props: map() | nil,
          prefix_path: String.t() | nil
        }
end
