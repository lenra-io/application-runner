defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.Action

  @callback run_action(Action.t()) :: {:ok, map()} | {:error, atom()}
  @callback get_data(Action.t()) :: {:ok, Action.t()}
  @callback save_data(Action.t(), map()) :: {:ok, map()} | {:error, map()}
end
