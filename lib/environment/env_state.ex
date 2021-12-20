defmodule ApplicationRunner.EnvState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:env_id, :app_name, :build_number, :env_supervisor_pid]
  defstruct [
    :env_id,
    :app_name,
    :build_number,
    :manifest,
    :env_supervisor_pid
  ]

  @type t :: %ApplicationRunner.EnvState{
          env_id: integer(),
          app_name: String.t(),
          build_number: integer(),
          manifest: map(),
          env_supervisor_pid: pid()
        }
end
