defmodule ApplicationRunner.Webhooks.WebhookServices do
  @moduledoc """
    The service that manages the webhooks.
  """

  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.ApplicationServices
  alias ApplicationRunner.Environment.MetadataAgent
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook

  def create(env_id, params) do
    Webhook.new(env_id, params)
    |> Repo.insert()
  end

  def create(env_id, user_id, params) do
    Webhook.new(env_id, %{params | user_id: user_id})
    |> Repo.insert()
  end

  def get(env_id) do
    Repo.all(from(w in Webhook, where: w.environment_id == ^env_id))
  end

  def get(env_id, user_id) do
    Repo.all(from(w in Webhook, where: w.environment_id == ^env_id and w.user_id == ^user_id))
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
