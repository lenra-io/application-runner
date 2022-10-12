defmodule ApplicationRunner.Webhooks.ServicesTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Contract.{Environment, User}
  alias ApplicationRunner.Environment.{Metadata, MetadataAgent}
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Crons.{Cron, CronServices}

  setup do
    {:ok, env} = Repo.insert(Environment.new())
    token = ApplicationRunner.AppChannel.do_create_env_token(env.id) |> elem(1)

    env_metadata = %Metadata{
      env_id: env.id,
      function_name: "test",
      token: token
    }

    {:ok, _} = start_supervised({MetadataAgent, env_metadata})

    user =
      %{email: "test@test.te"}
      |> User.new()
      |> Repo.insert!()

    {:ok, %{env_id: env.id, user_id: user.id}}
  end

  describe "create" do
    test "Cron create should work properly", %{
      env_id: env_id
    } do
      assert {:ok, _cron} =
               CronServices.create(env_id, %{
                 "listener_name" => "listener",
                 "cron_expression" => "* * * * *"
               })

      cron = Enum.at(Repo.all(Cron), 0)

      assert cron.listener_name == "listener"
      assert cron.cron_expression == "* * * * *"
      assert cron.environment_id == env_id
    end

    test "Cron create with user should work", %{
      env_id: env_id,
      user_id: user_id
    } do
      assert {:ok, cron} =
               CronServices.create(env_id, %{
                 "listener_name" => "listener",
                 "cron_expression" => "* * * * *",
                 "user_id" => user_id
               })

      cron_preload = Repo.preload(cron, :user)

      assert cron_preload.user.id == user_id
    end

    test "Cron create without listener_name and cron_expression should not work", %{
      env_id: env_id
    } do
      assert {:error, _reason} = CronServices.create(env_id, %{})
    end

    test "Cron create with invalid env_id should not work", %{} do
      assert {:error, _reason} =
               CronServices.create(-1, %{
                 "listener_name" => "listener",
                 "cron_expression" => "* * * * *"
               })
    end
  end

  describe "get_all" do
    test "Cron get_all should work properly", %{env_id: env_id} do
      assert {:ok, _cron} =
               Cron.new(env_id, %{
                 "listener_name" => "listener",
                 "cron_expression" => "* * * * *"
               })
               |> Repo.insert()

      crons = CronServices.get_all(env_id)

      assert Enum.at(crons, 0).listener_name == "listener"
    end

    test "Cron get_all with no Cron in db should return an empty array", %{env_id: env_id} do
      assert [] == CronServices.get_all(env_id)
    end

    test "Cron get_all should work properly with multiple Crons", %{env_id: env_id} do
      assert {:ok, _first} =
               Cron.new(env_id, %{"listener_name" => "1", "cron_expression" => "* * * * *"})
               |> Repo.insert()

      assert {:ok, _second} =
               Cron.new(env_id, %{"listener_name" => "2", "cron_expression" => "* * * * *"})
               |> Repo.insert()

      crons = CronServices.get_all(env_id)

      assert Enum.at(crons, 0).listener_name == "1"
      assert Enum.at(crons, 1).listener_name == "2"
    end

    test "get_all crons linked to specific user should work properly", %{env_id: env_id} do
      user =
        %{email: "test@test.te"}
        |> User.new()
        |> Repo.insert!()

      assert {:ok, _cron} =
               Cron.new(env_id, %{
                 "listener_name" => "user_specific",
                 "cron_expression" => "* * * * *",
                 "user_id" => user.id
               })
               |> Repo.insert()

      crons = CronServices.get_all(env_id, user.id)

      assert Enum.at(crons, 0).listener_name == "user_specific"
    end

    test "get_all Crons linked to specific user but no Crons in db should return empty array", %{
      env_id: env_id
    } do
      assert [] = CronServices.get_all(env_id, 1)
    end
  end

  describe "get" do
    test "get Cron should work properly", %{
      env_id: env_id
    } do
      assert {:ok, cron} =
               Cron.new(env_id, %{
                 "listener_name" => "listener",
                 "cron_expression" => "* * * * *"
               })
               |> Repo.insert()

      assert {:ok, cron_res} = CronServices.get(cron.id)

      assert cron_res.listener_name == "listener"
      assert cron_res.cron_expression == "* * * * *"
    end

    test "get not existing cron should return error", %{
      env_id: env_id
    } do
      assert {:error, %{reason: :error_404}} = CronServices.get(1)
    end
  end

  describe "update" do
    test "update Cron should work properly", %{
      env_id: env_id
    } do
      assert {:ok, cron} =
               Cron.new(env_id, %{
                 "listener_name" => "listener",
                 "cron_expression" => "* * * * *"
               })
               |> Repo.insert()

      assert {:ok, cron_res} = CronServices.get(cron.id)
      assert cron_res.listener_name == "listener"

      CronServices.update(cron_res, %{"listener_name" => "changed"})

      assert {:ok, updated_cron} = CronServices.get(cron.id)
      assert updated_cron.listener_name == "changed"
    end
  end

  describe "delete" do
  end
end
