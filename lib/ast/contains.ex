defmodule ApplicationRunner.AST.Contains do
  @moduledoc """
    This struct represent a $contains function.
  """
  @enforce_keys [:field, :value]
  defstruct [:field, :value]
end
