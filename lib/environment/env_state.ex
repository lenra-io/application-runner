defmodule ApplicationRunner.EnvState do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:env, :function_name, :assigns, :env_supervisor_pid]
  defstruct [
    :env,
    :function_name,
    :manifest,
    :env_supervisor_pid,
    :inactivity_timeout,
    :assigns,
    :ready?,
    :waiting_from
  ]

  @type t :: %ApplicationRunner.EnvState{
          env: term(),
          function_name: term(),
          manifest: map() | nil,
          env_supervisor_pid: pid(),
          inactivity_timeout: number(),
          assigns: term(),
          ready?: boolean(),
          waiting_from: list(pid())
        }
end
