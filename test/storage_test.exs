defmodule ApplicationRunner.StorageTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.Scheduler
  alias ApplicationRunner.Contract.{Environment, User}
  alias ApplicationRunner.CronHelper
  alias ApplicationRunner.Crons
  alias ApplicationRunner.Crons.Cron
  alias ApplicationRunner.Environment.{Metadata, MetadataAgent}
  alias ApplicationRunner.Repo
  alias ApplicationRunner.Storage

  setup do
    {:ok, env} = Repo.insert(Environment.new())
    token = ApplicationRunner.AppSocket.do_create_env_token(env.id) |> elem(1)

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

    on_exit(fn -> ApplicationRunner.Scheduler.delete_all_jobs() end)

    {:ok, %{env_id: env.id, user_id: user.id}}
  end

  describe "add_job" do
    test "should work properly", %{
      env_id: env_id
    } do
      job = CronHelper.basic_job(env_id)

      assert :ok = Storage.add_job(1, job)

      cron = Enum.at(Repo.all(Cron), 0)

      assert cron.listener_name == "listener"
      assert cron.schedule == "* * * * * *"
      assert cron.environment_id == env_id
    end

    test "without listener_name and schedule should not work", %{
      env_id: env_id
    } do
      assert {:error, %{reason: :invalid_params}} = Storage.add_job(1, Scheduler.new_job())
    end

    test "with invalid env_id should not work", %{} do
      job = CronHelper.basic_job(-1)

      assert {:error, %{errors: [environment_id: {"does not exist", _meta}]}} =
               Storage.add_job(1, job)
    end
  end

  describe "update_job" do
    test "should work properly", %{
      env_id: env_id
    } do
      job = CronHelper.basic_job(env_id)

      assert :ok = Storage.add_job(1, job)

      assert [cron] = Crons.all()
      assert cron.listener_name == "listener"

      updated_cron =
        Cron.update(cron, %{"listener_name" => "changed"})
        |> Ecto.Changeset.apply_changes()
        |> Crons.to_quantum()

      assert :ok = Storage.update_job(1, updated_cron)

      assert [updated_cron] = Crons.all()
      assert updated_cron.listener_name == "changed"
    end

    test "not existing job", %{
      env_id: env_id
    } do
      # Not adding this job to the Scheduler
      job = CronHelper.basic_job(env_id)

      updated_cron =
        job
        |> Crons.to_changeset()
        |> Ecto.Changeset.apply_changes()
        |> Cron.update(%{"listener_name" => "changed"})
        |> Ecto.Changeset.apply_changes()
        |> Crons.to_quantum()

      assert {:error, %{reason: :error_404}} = Storage.update_job(1, updated_cron)
    end
  end

  describe "delete_job" do
    test "should work properly", %{
      env_id: env_id
    } do
      job = CronHelper.basic_job(env_id)

      assert :ok = Storage.add_job(1, job)

      assert [%Cron{}] = Repo.all(Cron)

      assert :ok = Storage.delete_job(1, job.name)

      assert [] = Repo.all(Cron)
    end

    test "not existing job", %{env_id: env_id} do
      # Not adding this job to the Scheduler
      job = CronHelper.basic_job(env_id)

      assert {:error, %{reason: :error_404}} = Storage.delete_job(1, job.name)
    end
  end

  describe "jobs" do
    test "should work properly", %{
      env_id: env_id
    } do
      job = CronHelper.basic_job(env_id)

      assert :ok = Storage.add_job(1, job)

      assert [%Cron{}] = Repo.all(Cron)

      assert [%Quantum.Job{}] = Storage.jobs(1)
    end

    test "with no jobs in database", %{
      env_id: env_id
    } do
      assert [] = Storage.jobs(1)
    end

    test "with multiple jobs in database", %{
      env_id: env_id
    } do
      job = CronHelper.basic_job(env_id)
      job2 = CronHelper.basic_job(env_id)

      assert :ok = Storage.add_job(1, job)
      assert :ok = Storage.add_job(1, job2)

      assert [%Cron{}, %Cron{}] = Repo.all(Cron)

      assert [%Quantum.Job{}, %Quantum.Job{}] = Storage.jobs(1)
    end
  end
end
