defmodule ApplicationRunner.Environment.State do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:env_id, :function_name, :assigns, :env_supervisor_pid]
  defstruct [
    :env_id,
    :function_name,
    :manifest,
    :env_supervisor_pid,
    :inactivity_timeout,
    :assigns,
    :ready?,
    :waiting_from
  ]

  @type t :: %__MODULE__{
          env_id: term(),
          function_name: term(),
          manifest: map() | nil,
          env_supervisor_pid: pid(),
          inactivity_timeout: number(),
          assigns: term(),
          ready?: boolean(),
          waiting_from: list(pid())
        }
end
