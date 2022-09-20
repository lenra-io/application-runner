defmodule ApplicationRunner.WebhookServices do
  @moduledoc """
    The service that manages the webhooks.
  """
  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook

  def create(env_id, params) do
  end

  def get(env_id) do
    Repo.all(from(w in Webhook, where: w.environment_id == ^env_id))
  end

  def get(env_id, user_id) do
    Repo.all(from(w in Webhook, where: w.environment_id == ^env_id and w.user_id == ^user_id))
  end

  def trigger(webhook_uuid) do
  end
end
