defmodule ApplicationRunner.MongoStorageTest do
  use ApplicationRunner.ConnCase, async: false

  alias ApplicationRunner.MongoStorage
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Environment.MongoInstance

  defp setup_mongo(env_id, coll) do
    Mongo.start_link(MongoInstance.config(env_id))
    MongoStorage.delete_coll(env_id, coll)
  end

  describe "start_transaction" do
    test "should return session_uuid" do
      setup_mongo(1, "test")
      assert {:ok, _uuid} = MongoStorage.start_transaction(1)
    end

    test "should return error if mongo not started" do
      assert {:noproc,
              {GenServer, :call,
               [
                 {:via, :swarm, {ApplicationRunner.Environment.MongoInstance, 1}},
                 _any,
                 _timeout
               ]}} = catch_exit(MongoStorage.start_transaction(1))
    end
  end

  describe "create_doc" do
    test "create doc should create doc if transaction accepted" do
      setup_mongo(1, "test")
      assert {:ok, uuid} = MongoStorage.start_transaction(1)

      assert {:ok, doc} = MongoStorage.create_doc(1, "test", %{test: "test"}, uuid)

      assert :ok = MongoStorage.commit_transaction(uuid, 1)

      {:ok, docs} = MongoStorage.fetch_all_docs(1, "test") |> IO.inspect()

      assert length(docs) == 1

      assert Enum.at(docs, 0)["test"] == "test"
    end

    test "create doc should return error if uuid is incorrect" do
      setup_mongo(1, "test")
      assert {:ok, uuid} = MongoStorage.start_transaction(1)

      assert :badarg = catch_error(MongoStorage.create_doc(1, "test", %{test: "test"}, -1))
    end
  end

  describe "update_doc" do
    test "should add update" do
      setup_mongo(1, "test")
      assert {:ok, uuid} = MongoStorage.start_transaction(1)

      {:ok, %{"_id" => doc_id}} = MongoStorage.create_doc(1, "test", %{test: "test"})

      assert {:ok, updated_doc} =
               MongoStorage.update_doc(
                 1,
                 "test",
                 Jason.encode!(doc_id) |> Jason.decode!(),
                 %{
                   test: "test2"
                 },
                 uuid
               )

      assert :ok = MongoStorage.commit_transaction(uuid, 1)

      {:ok, docs} = MongoStorage.fetch_all_docs(1, "test")

      assert length(docs) == 1

      assert Enum.at(docs, 0)["test"] == "test2"
    end
  end

  describe "delete_doc" do
    test "should add delete" do
      setup_mongo(1, "test")
      assert {:ok, uuid} = MongoStorage.start_transaction(1)

      {:ok, %{"_id" => doc_id}} = MongoStorage.create_doc(1, "test", %{test: "test"})

      assert :ok =
               MongoStorage.delete_doc(1, "test", Jason.encode!(doc_id) |> Jason.decode!(), uuid)

      assert :ok = MongoStorage.commit_transaction(uuid, 1)

      {:ok, docs} = MongoStorage.fetch_all_docs(1, "test")

      assert length(docs) == 0
    end
  end

  describe "revert_transaction" do
    test "should revert update" do
      setup_mongo(1, "test")
      assert {:ok, uuid} = MongoStorage.start_transaction(1)

      {:ok, %{"_id" => doc_id}} = MongoStorage.create_doc(1, "test", %{test: "test"})

      assert {:ok, updated_doc} =
               MongoStorage.update_doc(
                 1,
                 "test",
                 Jason.encode!(doc_id) |> Jason.decode!(),
                 %{
                   test: "test2"
                 },
                 uuid
               )

      assert :ok = MongoStorage.revert_transaction(uuid, 1)

      {:ok, docs} = MongoStorage.fetch_all_docs(1, "test")

      assert length(docs) == 1

      assert Enum.at(docs, 0)["test"] == "test"
    end
  end
end
