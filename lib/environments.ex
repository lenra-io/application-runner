defmodule ApplicationRunner.Environments do
  @moduledoc """
    ApplicationRunner.Environments manage Environments.
  """
  defdelegate wait_until_ready(env_id), to: ApplicationRunner.Environments.Manager

  defdelegate reload_all_ui(env_id), to: ApplicationRunner.Environments.Manager

  defdelegate get_manifest(env_id), to: ApplicationRunner.Environments.Manager

  defdelegate ensure_env_started(env_id, env_state), to: ApplicationRunner.Environments.Managers

  defdelegate fetch_token(env_id), to: ApplicationRunner.Environments.Token
end
