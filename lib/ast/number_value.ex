defmodule ApplicationRunner.AST.NumberValue do
  @moduledoc """
    This struct represent a number value.
    in `%{"_id" => 42}`, `42` is the NumberValue

    The above NumberValue part is parsed into
    `%AST.NumberValue{value: 42}`
  """
  @enforce_keys [:value]
  defstruct [:value]
end
