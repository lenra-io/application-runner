defmodule ApplicationRunner.AST.In do
  @moduledoc """
  This struct represent a $and function.
  in `%{"$and" => [...]}` the `"$and" => [...]` is the and function.
  in `%{"_datastore" => "userData"}`, `%{...}` is a simplified version of the and function.

  The above examples are parsed into
  `%AST.And{clauses: [...]}`
  """
  @enforce_keys [:field, :values]
  defstruct [:field, :values]
end
