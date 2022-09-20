defmodule ApplicationRunner.WebhookServices do
  @moduledoc """
    The service that manages the webhooks.
  """

  alias ApplicationRunner.ApplicationServices
  alias ApplicationRunner.Environment.MetadataAgent
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook

  def create(env_id, params) do
  end

  def get(env_id) do
  end

  def trigger(webhook_uuid, payload) do
    case Repo.get(Webhook, webhook_uuid) do
      nil ->
        TechnicalError.error_404_tuple()

      webhook ->
        metadata = MetadataAgent.get_metadata(webhook.environment_id)

        ApplicationServices.run_listener(
          metadata.function_name,
          webhook.action,
          webhook.props,
          payload,
          metadata.token
        )
    end
  end
end
