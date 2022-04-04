defmodule ApplicationRunner.AST.Query do
  @moduledoc """
    This struct represent the query.
    it have a `ApplicationRunner.AST.Find` clause (:find) and a `ApplicationRunner.AST.Select` clause (:select)
  """
  @enforce_keys [:find, :select]
  defstruct [:find, :select]
end
