defmodule ApplicationRunner.AST.Eq do
  @moduledoc """
  This struct represent a $and function.
  in `%{"_datastore", %{"$eq" => "_users"}` the `"$eq" => "_users"` is the and function.
  in `%{"_datastore" => "_users"}`, `"_datastore" => "_users"` is a simplified version of the $eq function.

  The above examples are parsed into
  `%AST.Eq{right: %AST.DataKey{key: "_datastore"}, left: %AST.StringValue{value: "_users"}}`
  """

  @enforce_keys [:left, :right]
  defstruct [:left, :right]
end
