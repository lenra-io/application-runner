defmodule ApplicationRunner.MongoStorageTest do
  use ApplicationRunner.ConnCase, async: false

  alias ApplicationRunner.MongoStorage
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Environment.MongoInstance

  defp setup_mongo(env_id) do
    Mongo.start_link(MongoInstance.config(env_id))
  end

  describe "start_transaction" do
    test "should return an error if mongo not started" do
      assert BusinessError.mongo_not_started_tuple() == MongoStorage.start_transaction(0)
    end

    test "should return session_uuid" do
      setup_mongo(1) |> IO.inspect()
      Swarm.registered() |> IO.inspect()
      assert {:ok, _uuid} = MongoStorage.start_transaction(1)
    end
  end
end
