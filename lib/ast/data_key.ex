defmodule ApplicationRunner.AST.DataKey do
  @moduledoc """
    This struct represent a Data-referenced key.
    in `%{"_datastore" => "userData"}`, `"datastore"` is the DataKey

    The above example is parsed into
    `%AST.DataKey{key: "_datastore"}`
  """

  @enforce_keys [:key]
  defstruct [:key]
end
