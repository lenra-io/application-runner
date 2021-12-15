defmodule ApplicationRunner.EnvState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:env_id, :app_name, :build_number]
  defstruct [
    :env_id,
    :app_name,
    :build_number,
    :entrypoint
  ]

  @type t :: %ApplicationRunner.EnvState{
    env_id: integer(),
    app_name: String.t(),
    build_number: integer(),
    entrypoint: String.t() | nil
  }
end
