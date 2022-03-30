defmodule ApplicationRunner.AST.Find do
  @moduledoc """
    This struct represent the $find part of a query.
    in `%{"$find" => %{"_datastore" => "userData"}}`, `%{"_datastore" => "userData"}` is the Find part.

    The above example is parsed into
    `%AST.Find{
      clause: %AST.Eq{
        right: %AST.DataKey{key: "_datastore"},
        left: %AST.StringValue{value: "userData"}
      }
    }`

    The Find have only one clause. If there is a map with multiple key -> value, te clause is an `AST.And` clause.
  """
  @enforce_keys [:clause]
  defstruct [:clause]
end
