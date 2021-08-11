defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.Action

  @callback run_action(%Action{}) :: {:ok, map()} | {:error, atom()}
  @callback get_data(%Action{}) :: {:ok, map()}
  @callback save_data(%Action{}, map()) :: {:ok, map()} | {:error, map()}
end
