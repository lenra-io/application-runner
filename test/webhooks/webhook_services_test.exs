defmodule ApplicationRunner.WebhookServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.Environment
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook
  alias ApplicationRunner.WebhookServices

  setup do
    {:ok, env} = Repo.insert(Environment.new())
    {:ok, env_id: env.id}
  end

  test "Webhook create should work properly", %{env_id: env_id} do
    assert {:ok, webhook} = WebhookServices.create(env_id, %{"action" => "listener"})

    webhook = Enum.at(Repo.all(Webhook), 0)

    assert webhook.action == "listener"
    assert webhook.environment_id == env_id
  end

  test "Webhook create with user should work", %{env_id: env_id} do
    assert {:ok, webhook} =
             WebhookServices.create(env_id, %{"action" => "listener", "user_id" => 1})
  end

  test "Webhook create without action should not work", %{env_id: env_id} do
    assert {:error, reason} = WebhookServices.create(env_id, %{})
  end

  test "Webhook create with invalid env_id should not work", %{env_id: _env_id} do
    assert {:error, reason} = WebhookServices.create(-1, %{"action" => "listener"})
  end
end
