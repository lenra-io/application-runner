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

  test "Webhook get should work properly", %{env_id: env_id} do
    assert {:ok, first} =
             Webhook.new(env_id, %{"action" => "listener"})
             |> Repo.insert()

    webhooks = WebhookServices.get(env_id)

    assert Enum.at(webhooks, 0).action == "listener"
  end

  test "Webhook get should work properly with multiple webhooks", %{env_id: env_id} do
    assert {:ok, first} =
             Webhook.new(env_id, %{"action" => "first"})
             |> Repo.insert()

    assert {:ok, second} =
             Webhook.new(env_id, %{"action" => "second"})
             |> Repo.insert()

    webhooks = WebhookServices.get(env_id)

    assert Enum.at(webhooks, 0).action == "first"
    assert Enum.at(webhooks, 1).action == "second"
  end
end
