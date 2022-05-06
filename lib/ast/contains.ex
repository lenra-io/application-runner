defmodule ApplicationRunner.AST.Contains do
  @moduledoc """
  This struct represent a $and function.
  in `%{"$and" => [...]}` the `"$and" => [...]` is the and function.
  in `%{"_datastore" => "userData"}`, `%{...}` is a simplified version of the and function.

  The above examples are parsed into
  `%AST.And{clauses: [...]}`
  """
  @enforce_keys [:field, :clauses]
  defstruct [:field, :clauses]
end
