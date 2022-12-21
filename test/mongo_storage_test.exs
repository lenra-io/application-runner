defmodule ApplicationRunner.MongoStorageTest do
  use ApplicationRunner.ConnCase, async: false

  alias ApplicationRunner.MongoStorage
  alias ApplicationRunner.Errors.BusinessError
  alias ApplicationRunner.Environment.MongoInstance

  defp setup_mongo(env_id) do
    Mongo.start_link(MongoInstance.config(env_id))
  end

  describe "start_transaction" do
    test "should return session_uuid" do
      setup_mongo(1)
      Swarm.registered()
      assert {:ok, _uuid} = MongoStorage.start_transaction(1)
    end
  end
end
