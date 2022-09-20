defmodule ApplicationRunner.WebhookServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.{Environment, User}
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook
  alias ApplicationRunner.WebhookServices

  setup do
    {:ok, env} = Repo.insert(Environment.new())
    {:ok, env_id: env.id}
  end

  test "Webhook get should work properly", %{env_id: env_id} do
    assert {:ok, _webhook} =
             Webhook.new(env_id, %{"action" => "listener"})
             |> Repo.insert()

    webhooks = WebhookServices.get(env_id)

    assert Enum.at(webhooks, 0).action == "listener"
  end

  test "Webhook get with no webhook in db should return an empty array", %{env_id: env_id} do
    assert [] == WebhookServices.get(env_id)
  end

  test "Webhook get should work properly with multiple webhooks", %{env_id: env_id} do
    assert {:ok, _first} =
             Webhook.new(env_id, %{"action" => "first"})
             |> Repo.insert()

    assert {:ok, _second} =
             Webhook.new(env_id, %{"action" => "second"})
             |> Repo.insert()

    webhooks = WebhookServices.get(env_id)

    assert Enum.at(webhooks, 0).action == "first"
    assert Enum.at(webhooks, 1).action == "second"
  end

  test "Get webhooks linked to specific user should work properly", %{env_id: env_id} do
    user =
      %{email: "test@test.te"}
      |> User.new()
      |> Repo.insert!()

    assert {:ok, _webhook} =
             Webhook.new(env_id, %{"action" => "user_specific_webhook", "user_id" => user.id})
             |> Repo.insert()

    webhooks = WebhookServices.get(env_id, user.id)

    assert Enum.at(webhooks, 0).action == "user_specific_webhook"
  end

  test "Get webhooks linked to specific user but no webhook in db should return empty array", %{env_id: env_id} do
    assert [] = WebhookServices.get(env_id, 1)
  end
end
