defmodule ApplicationRunner.WebhookServices do
  @moduledoc """
    The service that manages the webhooks.
  """

  alias ApplicationRunner.ApplicationServices
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook


  def create(env_id, params) do
  end

  def get(env_id) do
  end

  def trigger(webhook_uuid, payload) do
    webhook = Repo.get(Webhook, webhook_uuid)

    ApplicationServices.run_listener(<state>, webhook.action, payload, %{})
  end
end
