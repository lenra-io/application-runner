defmodule ApplicationRunner.Environment do
  @moduledoc """
    ApplicationRunner.Environment manage Environments.
  """

  # defdelegate wait_until_ready(env_id), to: ApplicationRunner.Environment.Manager

  # defdelegate reload_all_ui(env_id), to: ApplicationRunner.Environment.Manager

  defdelegate get_manifest(env_id), to: ApplicationRunner.Environment.ManifestHandler

  defdelegate ensure_env_started(env_metadata),
    to: ApplicationRunner.Environment.DynamicSupervisor

  defdelegate fetch_token(env_id), to: ApplicationRunner.Environment.MetadataAgent
end
