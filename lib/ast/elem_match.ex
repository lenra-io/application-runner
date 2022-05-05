defmodule ApplicationRunner.AST.ElemMatch do
  @moduledoc """
  This struct represent a $elemMatch function.
  in `%{"_datastore", %{"$elemMatch" => {"_users", "todos"}}` the "$elemMatch" => {"_users", "todos"} is a list of $eq function.

  The above examples are parsed into
  `%AST.Eq{field: %AST.DataKey{key: "_datastore"}, left: [%AST.StringValue{value: "_users"}}, %AST.StringValue{value: "todos"}}]`
  """

  @enforce_keys [:field, :matchs]
  defstruct [:field, :matchs]
end
