defmodule ApplicationRunner.AST.ArrayValue do
  @moduledoc """
    This struct represent an Array of values.
    in `%{"_refs" => [1, 2, 3]}`, `[1, 2, 3]` is the ArrayValue
  """
  @enforce_keys [:values]
  defstruct [:values]
end
