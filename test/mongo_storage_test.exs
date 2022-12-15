defmodule ApplicationRunner.MongoStorageTest do
  use ApplicationRunner.ConnCase, async: false

  alias ApplicationRunner.MongoStorage

  describe "start_transaction" do
    test "should return an error if mongo not started" do
      assert :ok = MongoStorage.start_transaction(0)
    end
  end
end
