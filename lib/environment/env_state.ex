defmodule ApplicationRunner.EnvState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:env_id, :assigns, :env_supervisor_pid]
  defstruct [
    :env_id,
    :manifest,
    :env_supervisor_pid,
    :inactivity_timeout,
    :assigns,
    :ready?,
    :waiting_from
  ]

  @type t :: %ApplicationRunner.EnvState{
          env_id: integer(),
          manifest: map(),
          env_supervisor_pid: pid(),
          inactivity_timeout: number(),
          assigns: term(),
          ready?: boolean(),
          waiting_from: list(pid())
        }
end
