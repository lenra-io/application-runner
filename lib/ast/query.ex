defmodule ApplicationRunner.AST.Query do
  @enforce_keys [:find, :select]
  defstruct [:find, :select]
end
