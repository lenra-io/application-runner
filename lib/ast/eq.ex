defmodule ApplicationRunner.AST.Eq do
  @moduledoc """
  This struct represent a $and function.
  in `%{"_datastore", %{"$eq" => "userData"}` the `"$eq" => "userData"` is the and function.
  in `%{"_datastore" => "userData"}`, `"_datastore" => "userData"` is a simplified version of the $eq function.

  The above examples are parsed into
  `%AST.Eq{right: %AST.DataKey{key: "_datastore"}, left: %AST.StringValue{value: "userData"}}`
  """

  @enforce_keys [:left, :right]
  defstruct [:left, :right]
end
