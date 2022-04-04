defmodule ApplicationRunner.AST.StringValue do
  @moduledoc """
    This struct represent a string value.
    in `%{"_datastore" => "userData"}`, `"userData"` is the StringValue

    The above StringValue part is parsed into
    `%AST.StringValue{value: "userData"}`
  """
  @enforce_keys [:value]
  defstruct [:value]
end
