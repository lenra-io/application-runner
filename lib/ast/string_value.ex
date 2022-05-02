defmodule ApplicationRunner.AST.StringValue do
  @moduledoc """
    This struct represent a string value.
    in `%{"_datastore" => "_users"}`, `"_users"` is the StringValue

    The above StringValue part is parsed into
    `%AST.StringValue{value: "_users"}`
  """
  @enforce_keys [:value]
  defstruct [:value]
end
