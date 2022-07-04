defmodule ApplicationRunner.Environment do
  @moduledoc """
    ApplicationRunner.Environment manage Environment.
  """
  defdelegate wait_until_ready(env_id), to: ApplicationRunner.Environment.Manager

  defdelegate reload_all_ui(env_id), to: ApplicationRunner.Environment.Manager

  defdelegate get_manifest(env_id), to: ApplicationRunner.Environment.Manager

  defdelegate ensure_env_started(env_id, env_state), to: ApplicationRunner.Environment.Managers
end
