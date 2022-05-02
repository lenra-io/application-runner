defmodule ApplicationRunner.AST.Find do
  @moduledoc """
    This struct represent the $find part of a query.
    in `%{"$find" => %{"_datastore" => "_users"}}`, `%{"_datastore" => "_users"}` is the Find part.

    The above example is parsed into
    `%AST.Find{
      clause: %AST.Eq{
        right: %AST.DataKey{key: "_datastore"},
        left: %AST.StringValue{value: "_users"}
      }
    }`

    The Find have only one clause. If there is a map with multiple key -> value, te clause is an `AST.And` clause.
  """
  @enforce_keys [:clause]
  defstruct [:clause]
end
