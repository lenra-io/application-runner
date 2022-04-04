defmodule ApplicationRunner.AST.ValueRef do
  @moduledoc """
    This struct represent a value that reference the data.
    in `%{"@score" => 42}`, `@score` is the ValueRef

    The above ValueRef part is parsed into
    `%AST.ValueRef{ref: "@score"}`
  """

  @enforce_keys [:ref]
  defstruct [:ref]
end
