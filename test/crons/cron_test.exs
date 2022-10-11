defmodule ApplicationRunner.Crons.CronTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.{Environment, User}
  alias ApplicationRunner.Crons.Cron
  alias ApplicationRunner.Repo

  test "Insert Cron into database successfully" do
    env =
      Environment.new()
      |> Repo.insert!()

    date = Date.utc_today()

    Cron.new(env.id, %{
      "cron_expression" => "* * * * *",
      "listener_name" => "listener",
      "props" => %{
        "prop1" => "1",
        "prop2" => "2"
      },
      "last_run_date" => date
    })
    |> Repo.insert!()

    cron = Enum.at(Repo.all(Cron), 0)

    assert cron.cron_expression == "* * * * *"
    assert cron.listener_name == "listener"

    assert cron.props == %{
             "prop1" => "1",
             "prop2" => "2"
           }

    assert cron.last_run_date == date
    assert cron.should_run_missed_steps == false
  end

  test "Insert Cron into database successfully (should run missed steps)" do
    env =
      Environment.new()
      |> Repo.insert!()

    Cron.new(env.id, %{
      "cron_expression" => "* * * * *",
      "listener_name" => "listener",
      "should_run_missed_steps" => true
    })
    |> Repo.insert!()

    cron = Enum.at(Repo.all(Cron), 0)

    assert cron.cron_expression == "* * * * *"
    assert cron.listener_name == "listener"

    assert cron.should_run_missed_steps == true
  end

  test "Cron with invalid cron expression should not work" do
    env =
      Environment.new()
      |> Repo.insert!()

    cron =
      Cron.new(env.id, %{
        "cron_expression" => "This is not a valid cron expression",
        "listener_name" => "listener",
        "props" => %{
          "prop1" => "1",
          "prop2" => "2"
        }
      })

    assert cron.errors == [cron_expression: {"Cron Expression is malformed.", []}]
  end

  test "Cron with invalid env_id should not work" do
    cron =
      Cron.new(1, %{
        "cron_expression" => "* * * * *",
        "listener_name" => "listener",
        "props" => %{
          "prop1" => "1",
          "prop2" => "2"
        }
      })

    assert_raise Ecto.InvalidChangesetError, fn -> Repo.insert!(cron) end
  end

  test "Cron without required parameters should not work" do
    cron =
      Cron.new(1, %{
        "props" => %{
          "prop1" => "1",
          "prop2" => "2"
        }
      })

    assert cron.valid? == false
    assert [{:listener_name, _err}, {:cron_expression, _error}] = cron.errors
  end

  test "Insert Cron with no props into database successfully" do
    env =
      Environment.new()
      |> Repo.insert!()

    Cron.new(env.id, %{
      "cron_expression" => "* * * * *",
      "listener_name" => "listener"
    })
    |> Repo.insert!()

    cron = Enum.at(Repo.all(Cron), 0)

    assert cron.cron_expression == "* * * * *"
    assert cron.listener_name == "listener"
  end

  test "Insert Cron with user into database successfully" do
    env =
      Environment.new()
      |> Repo.insert!()

    user =
      User.new(%{"email" => "test@lenra.io"})
      |> Repo.insert!()

    Cron.new(env.id, %{
      "cron_expression" => "* * * * *",
      "listener_name" => "listener",
      "user_id" => user.id
    })
    |> Repo.insert!()

    cron = Enum.at(Repo.all(Cron), 0)

    assert cron.cron_expression == "* * * * *"
    assert cron.user_id == user.id

    preload_user = Repo.preload(cron, :user)

    assert preload_user.user.id == user.id
  end
end
