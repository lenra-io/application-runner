defmodule ApplicationRunner.Webhooks.WebhookTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.Environment
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Webhooks.Webhook

  test "Insert Webhook into database successfully" do
    env =
      Environment.new()
      |> Repo.insert!()

    Webhook.new(env.id, %{
      "action" => "test",
      "props" => %{
        "prop1" => "1",
        "prop2" => "2"
      }
    })
    |> Repo.insert!()

    webhook = Enum.at(Repo.all(Webhook), 0)

    assert webhook.action == "test"

    assert webhook.props == %{
             "prop1" => "1",
             "prop2" => "2"
           }
  end
end