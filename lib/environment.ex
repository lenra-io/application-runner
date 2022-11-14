defmodule ApplicationRunner.Environment do
  @moduledoc """
    ApplicationRunner.Environment manage Environments.
  """

  alias ApplicationRunner.Environment

  defdelegate get_manifest(env_id), to: Environment.ManifestHandler

  defdelegate ensure_env_started(env_metadata), to: Environment.DynamicSupervisor

  defdelegate fetch_token(env_id), to: Environment.MetadataAgent

  defdelegate create_metadata(env_id), to: Environment.MetadataAgent
end
