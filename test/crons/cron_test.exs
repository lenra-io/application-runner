defmodule ApplicationRunner.Crons.CronTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.{Environment, User}
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Crons.Cron

  test "Insert Cron into database successfully" do
    env =
      Environment.new()
      |> Repo.insert!()

    Cron.new(env.id, %{
      "cron" => "* * * * *",
      "listener_name" => "listener",
      "props" => %{
        "prop1" => "1",
        "prop2" => "2"
      }
    })
    |> Repo.insert!()

    cron = Enum.at(Repo.all(Cron), 0)

    assert cron.cron == "* * * * *"
    assert cron.listener_name == "listener"

    assert cron.props == %{
             "prop1" => "1",
             "prop2" => "2"
           }
  end

  test "Cron with invalid cron expression should not work" do
    env =
      Environment.new()
      |> Repo.insert!()

    cron =
      Cron.new(env.id, %{
        "cron" => "This is not a valid cron expression",
        "listener_name" => "listener",
        "props" => %{
          "prop1" => "1",
          "prop2" => "2"
        }
      })

    assert cron.errors == [cron: {"Cron Expression is malformed.", []}]
  end

  # test "Webhook without action should not work" do
  #   webhook =
  #     Webhook.new(1, %{
  #       "props" => %{
  #         "prop1" => "1",
  #         "prop2" => "2"
  #       }
  #     })

  #   assert webhook.valid? == false
  #   assert [action: _reason] = webhook.errors
  # end

  # test "Insert Webhook with no props into database successfully" do
  #   env =
  #     Environment.new()
  #     |> Repo.insert!()

  #   Webhook.new(env.id, %{
  #     "action" => "test"
  #   })
  #   |> Repo.insert!()

  #   webhook = Enum.at(Repo.all(Webhook), 0)

  #   assert webhook.action == "test"
  # end

  # test "Insert Webhook with user into database successfully" do
  #   env =
  #     Environment.new()
  #     |> Repo.insert!()

  #   user =
  #     User.new(%{"email" => "test@lenra.io"})
  #     |> Repo.insert!()

  #   Webhook.new(env.id, %{
  #     "user_id" => user.id,
  #     "action" => "test"
  #   })
  #   |> Repo.insert!()

  #   webhook = Enum.at(Repo.all(Webhook), 0)

  #   assert webhook.action == "test"
  #   assert webhook.user_id == user.id

  #   preload_user = Repo.preload(webhook, :user)

  #   assert preload_user.user.id == user.id
  # end
end
