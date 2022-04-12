defmodule ApplicationRunner.AST.MeRef do
  @moduledoc """
    This struct represent the "@me" ref that will be replaced by the current user_id

    `%AST.Me{id: 42}`
  """

  @enforce_keys [:id]
  defstruct [:id]
end
