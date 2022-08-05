defmodule Environment.QueryServerTest do
  use ExUnit.Case

  alias ApplicationRunner.Environment.{QueryDynSup}

  def insert_event(idx, coll \\ "test") do
    %{
      "operationType" => "insert",
      "ns" => %{
        "coll" => coll
      },
      "documentKey" => %{
        "_id" => "#{idx}"
      },
      "fullDocument" => %{
        "_id" => "#{idx}",
        "name" => "test#{idx}",
        "idx" => idx
      }
    }
  end

  def update_event(idx, coll \\ "test") do
    %{
      "operationType" => "update",
      "ns" => %{
        "coll" => coll
      },
      "documentKey" => %{
        "_id" => "#{idx}"
      },
      "fullDocument" => %{
        "_id" => "#{idx}",
        "name" => "new_test#{idx}",
        "foo" => "bar"
      }
    }
  end

  def replace_event(idx, coll \\ "test") do
    %{
      "operationType" => "replace",
      "ns" => %{
        "coll" => coll
      },
      "documentKey" => %{
        "_id" => "#{idx}"
      },
      "fullDocument" => %{
        "_id" => "#{idx}",
        "name" => "new_test#{idx}",
        "foo" => "bar"
      }
    }
  end

  def delete_event(idx, coll \\ "test") do
    %{
      "operationType" => "delete",
      "ns" => %{
        "coll" => coll
      },
      "documentKey" => %{
        "_id" => "#{idx}"
      }
    }
  end

  def drop_event(coll) do
    %{
      "operationType" => "drop",
      "ns" => %{
        "coll" => coll
      }
    }
  end

  def rename_event(from, to) do
    %{
      "operationType" => "rename",
      "ns" => %{
        "coll" => from
      },
      "to" => %{
        "coll" => to
      }
    }
  end

  setup do
    start_supervised(QueryDynSup)

    # Swarm seems to be a bit too slow to add/remove to groups when a genserver start/stop leading to
    # some random error in unit test.
    # I'm adding a small sleep to hopefully prevent this.
    :timer.sleep(10)
    :ok
  end

  describe "QueryServer setup" do
    test "should start with coll and query in the correct swarm group" do
      assert [] = Swarm.members({:query, "42"})
      assert :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      assert [_pid] = Swarm.members({:query, "42"})
    end

    test "should have the correct state" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert %{coll: "test", query: %{"clauses" => [], "pos" => "expression"}, data: []} =
               :sys.get_state(pid)
    end

    test "should return :ok for the {:mongo_event, event} call" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
    end

    test "should be able to called a group using Swarm.multi_call" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      :ok = QueryDynSup.ensure_child_started("test", "{}", "43")
      :ok = QueryDynSup.ensure_child_started("foo", "{}", "43")
      assert [_pid] = Swarm.members({:query, "42"})
      assert [_pid, _pid2] = Swarm.members({:query, "43"})

      assert [:ok] = Swarm.multi_call({:query, "42"}, {:mongo_event, insert_event(1)})
      assert [:ok, :ok] = Swarm.multi_call({:query, "43"}, {:mongo_event, insert_event(1)})
    end

    test "should start once with the same coll/query" do
      assert {:ok, pid} = QueryDynSup.start_child("test", "{}", "42")

      assert {:error, {:already_started, ^pid}} = QueryDynSup.start_child("test", "{}", "42")
    end
  end

  describe "QueryServer insert" do
    test "should insert data for the correct coll" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(2)})

      assert %{
               coll: "test",
               data: [
                 %{"_id" => "1", "idx" => 1, "name" => "test1"},
                 %{"_id" => "2", "idx" => 2, "name" => "test2"}
               ]
             } = :sys.get_state(pid)
    end

    test "should NOT insert data for the wrong coll" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(2, "foo")})

      assert %{
               coll: "test",
               data: [%{"_id" => "1"}]
             } = :sys.get_state(pid)
    end

    test "should NOT insert data if the query does not match the new element" do
      :ok = QueryDynSup.ensure_child_started("test", "{\"idx\": {\"$lt\": 3}}", "44")
      [pid] = Swarm.members({:query, "44"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(2)})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(3)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1"}, %{"_id" => "2"}]
             } = :sys.get_state(pid)
    end
  end

  describe "QueryServer update" do
    test "should update an older data if _id is the same" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, update_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "new_test1", "foo" => "bar"}]
             } = :sys.get_state(pid)
    end

    test "should NOT update an older data if _id is different" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, update_event(2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end

    test "should NOT update an older data if the coll is different" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, update_event(1, "foo")})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end

    test "should remove the old data if _id is the same but query does not match anymore" do
      :ok = QueryDynSup.ensure_child_started("test", "{\"name\": \"test1\"}", "45")
      [pid] = Swarm.members({:query, "45"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, update_event(1)})

      assert %{
               coll: "test",
               data: []
             } = :sys.get_state(pid)
    end
  end

  describe "QueryServer replace" do
    test "should replace an older data if _id is the same" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, replace_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "new_test1", "foo" => "bar"}]
             } = :sys.get_state(pid)
    end

    test "should NOT replace an older data if _id is different" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, replace_event(2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end

    test "should NOT replace an older data if the coll is different" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, replace_event(1, "foo")})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end

    test "should remove the old data if _id is the same but query does not match anymore" do
      :ok = QueryDynSup.ensure_child_started("test", "{\"name\": \"test1\"}", "46")
      [pid] = Swarm.members({:query, "46"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, replace_event(1)})

      assert %{
               coll: "test",
               data: []
             } = :sys.get_state(pid)
    end
  end

  describe "QueryServer delete" do
    test "should delete an older data if _id and coll is the same" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, delete_event(1)})

      assert %{
               coll: "test",
               data: []
             } = :sys.get_state(pid)
    end

    test "should NOT delete an older data if coll is different" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, delete_event(1, "foo")})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end

    test "should NOT delete an older data if id is different" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, delete_event(2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end
  end

  describe "QueryServer drop coll" do
    test "should stop the genserver when drop the coll" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert Process.alive?(pid)
      assert :ok = GenServer.call(pid, {:mongo_event, drop_event("test")})
      assert not Process.alive?(pid)
    end

    test "should NOT stop the genserver when drop another coll" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert Process.alive?(pid)
      assert :ok = GenServer.call(pid, {:mongo_event, drop_event("foo")})
      assert Process.alive?(pid)
    end
  end

  describe "QueryServer rename coll" do
    test "should rename the coll and still work" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{coll: "test", data: [%{"_id" => "1"}]} = :sys.get_state(pid)
      assert :ok = GenServer.call(pid, {:mongo_event, rename_event("test", "bar")})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(2, "bar")})

      assert %{coll: "bar", data: [%{"_id" => "1"}, %{"_id" => "2"}]} = :sys.get_state(pid)
    end

    test "should ignore the rename if namesapce coll is different" do
      :ok = QueryDynSup.ensure_child_started("test", "{}", "42")
      [pid] = Swarm.members({:query, "42"})

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
      assert %{coll: "test", data: [%{"_id" => "1"}]} = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, rename_event("foo", "bar")})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(2)})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(3, "bar")})

      assert %{coll: "test", data: [%{"_id" => "1"}, %{"_id" => "2"}]} = :sys.get_state(pid)
    end
  end
end
