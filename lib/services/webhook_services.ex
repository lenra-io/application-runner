defmodule ApplicationRunner.WebhookServices do
  @moduledoc """
    The service that manages the webhooks.
  """

  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook

  def create(env_id, params) do
    Webhook.new(env_id, params)
    |> Repo.insert()
  end

  def get(env_id) do
  end

  def trigger(webhook_uuid) do
  end
end
