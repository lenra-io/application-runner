defmodule ApplicationRunner.AST.In do
  @moduledoc """
  This struct represent a $in function.
  """
  @enforce_keys [:field, :values]
  defstruct [:field, :values]
end
