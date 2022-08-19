defmodule Environment.QueryServerTest do
  use ExUnit.Case

  alias ApplicationRunner.Environment.{QueryDynSup, QueryServer, Widget}

  @env_id 1337

  def insert_event(idx, coll \\ "test", id \\ nil, time \\ System.os_time(:microsecond)) do
    id = if id == nil, do: idx, else: id

    %{
      "_id" => id,
      "clusterTime" => time,
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

  def update_event(idx, coll \\ "test", id \\ nil, time \\ System.os_time(:microsecond)) do
    id = if id == nil, do: idx, else: id

    %{
      "_id" => id,
      "clusterTime" => time,
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

  def replace_event(idx, coll \\ "test", id \\ nil, time \\ System.os_time(:microsecond)) do
    id = if id == nil, do: idx, else: id

    %{
      "_id" => id,
      "clusterTime" => time,
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

  def delete_event(idx, coll \\ "test", id \\ nil, time \\ System.os_time(:microsecond)) do
    id = if id == nil, do: idx, else: id

    %{
      "_id" => id,
      "clusterTime" => time,
      "operationType" => "delete",
      "ns" => %{
        "coll" => coll
      },
      "documentKey" => %{
        "_id" => "#{idx}"
      }
    }
  end

  def drop_event(coll, id \\ 1, time \\ System.os_time(:microsecond)) do
    %{
      "_id" => id,
      "clusterTime" => time,
      "operationType" => "drop",
      "ns" => %{
        "coll" => coll
      }
    }
  end

  def rename_event(from, to, id \\ 1, time \\ System.os_time(:microsecond)) do
    %{
      "_id" => id,
      "clusterTime" => time,
      "operationType" => "rename",
      "ns" => %{
        "coll" => from
      },
      "to" => %{
        "coll" => to
      }
    }
  end

  def loop(name, pid) do
    receive do
      msg ->
        send(pid, {name, msg})
        loop(name, pid)
    end
  end

  def spawn_pass_process(name) do
    pid = spawn(Environment.QueryServerTest, :loop, [name, self()])
    Swarm.register_name({:test_pass_process, name}, pid)
    pid
  end

  setup do
    start_supervised({QueryDynSup, env_id: @env_id})

    mongo_name = {:global, {:test, Mongo}}

    start_supervised({
      Mongo,
      url: "mongodb://localhost:27017/test", name: mongo_name
    })

    Mongo.drop_collection(mongo_name, "test")

    # Register self in swarm to allow grouping
    :yes = Swarm.register_name(:test_process, self())

    # Swarm seems to be a bit too slow to add/remove to groups when a genserver start/stop leading to
    # some random error in unit test.
    # I'm adding a small sleep to hopefully prevent this.
    :timer.sleep(50)

    {:ok, %{mongo_name: mongo_name}}
  end

  describe "QueryServer setup" do
    test "should start with coll and query in the correct swarm group" do
      assert [] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [_pid] = Swarm.members(QueryServer.group_name("42"))
    end

    test "should have the correct state" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert %{coll: "test", query: %{"clauses" => [], "pos" => "expression"}, data: []} =
               :sys.get_state(pid)
    end

    test "should get the correct data from the mongo db", %{mongo_name: mongo_name} do
      data = [
        %{"name" => "test1", "idx" => 1},
        %{"name" => "test2", "idx" => 2},
        %{"name" => "test3", "idx" => 3}
      ]

      Mongo.insert_many!(mongo_name, "test", data)

      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert %{
               coll: "test",
               query: %{"clauses" => [], "pos" => "expression"},
               data: [
                 %{"name" => "test1", "idx" => 1, "_id" => _},
                 %{"name" => "test2", "idx" => 2, "_id" => _},
                 %{"name" => "test3", "idx" => 3, "_id" => _}
               ]
             } = :sys.get_state(pid)
    end

    test "should return :ok for the {:mongo_event, event} call" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
    end

    test "should be able to called a group using Swarm.multi_call" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      :ok = QueryDynSup.ensure_child_started(@env_id, "43", "test", "{}")
      :ok = QueryDynSup.ensure_child_started(@env_id, "43", "foo", "{}")
      assert [pid1] = Swarm.members(QueryServer.group_name("42"))
      assert [_pid2, _pid3] = pids = Swarm.members(QueryServer.group_name("43"))
      # the two group share the same "test", "{}" server
      assert pid1 in pids

      assert [:ok] =
               Swarm.multi_call(QueryServer.group_name("42"), {:mongo_event, insert_event(1)})

      assert [:ok, :ok] =
               Swarm.multi_call(QueryServer.group_name("43"), {:mongo_event, insert_event(1)})
    end

    test "should start once with the same coll/query" do
      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [^pid] = Swarm.members(QueryServer.group_name("42"))
    end

    test "should be registered with a specific name" do
      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [pid] = Swarm.members(QueryServer.group_name("42"))

      name = {QueryServer, @env_id, "test", "{}"}
      assert ^name = QueryServer.get_name(@env_id, "test", "{}")
      assert ^pid = Swarm.whereis_name(name)
    end

    test "should stop after timeout (100ms) passed" do
      assert :ok =
               QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}",
                 inactivity_timeout: 100
               )

      assert [pid] = Swarm.members(QueryServer.group_name("42"))
      assert Process.alive?(pid)
      :timer.sleep(60)
      assert Process.alive?(pid)
      :timer.sleep(60)
      assert not Process.alive?(pid)
    end

    test "should extend timeout (100ms) if a message is sent" do
      assert :ok =
               QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}",
                 inactivity_timeout: 100
               )

      assert [pid] = Swarm.members(QueryServer.group_name("42"))
      assert Process.alive?(pid)
      :timer.sleep(60)
      assert Process.alive?(pid)
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
      :timer.sleep(60)
      assert Process.alive?(pid)
      :timer.sleep(60)
      assert not Process.alive?(pid)
    end
  end

  describe "QueryServer prevent handling duplicate event" do
    test "should reject two event with same id and timestamp" do
      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [pid] = Swarm.members(QueryServer.group_name("42"))
      timestamp = System.os_time(:microsecond)

      GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1, timestamp)})
      assert %{data: [%{"_id" => "1"}]} = :sys.get_state(pid)
      GenServer.call(pid, {:mongo_event, insert_event(2, "test", 1, timestamp)})
      assert %{data: [%{"_id" => "1"}]} = :sys.get_state(pid)
    end

    test "should handle two event with same timestamp but different ids" do
      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [pid] = Swarm.members(QueryServer.group_name("42"))
      timestamp = System.os_time(:microsecond)

      GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1, timestamp)})
      assert %{data: [%{"_id" => "1"}]} = :sys.get_state(pid)
      GenServer.call(pid, {:mongo_event, insert_event(2, "test", 2, timestamp)})
      assert %{data: [%{"_id" => "1"}, %{"_id" => "2"}]} = :sys.get_state(pid)
    end

    test "should handle N event incremental ids and timestamps" do
      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [pid] = Swarm.members(QueryServer.group_name("42"))
      timestamp = System.os_time(:microsecond)

      GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1, timestamp)})
      assert %{data: [%{"_id" => "1"}]} = :sys.get_state(pid)
      GenServer.call(pid, {:mongo_event, insert_event(2, "test", 2, timestamp + 100)})
      assert %{data: [%{"_id" => "1"}, %{"_id" => "2"}]} = :sys.get_state(pid)
      GenServer.call(pid, {:mongo_event, insert_event(3, "test", 3, timestamp + 200)})
      assert %{data: [%{"_id" => "1"}, %{"_id" => "2"}, %{"_id" => "3"}]} = :sys.get_state(pid)
    end

    test "should reject an event with older timestamp" do
      assert :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      assert [pid] = Swarm.members(QueryServer.group_name("42"))
      timestamp = System.os_time(:microsecond)

      GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1, timestamp)})
      assert %{data: [%{"_id" => "1"}]} = :sys.get_state(pid)
      GenServer.call(pid, {:mongo_event, insert_event(2, "test", 2, timestamp + 100)})
      assert %{data: [%{"_id" => "1"}, %{"_id" => "2"}]} = :sys.get_state(pid)
      GenServer.call(pid, {:mongo_event, insert_event(3, "test", 3, timestamp + 50)})
      assert %{data: [%{"_id" => "1"}, %{"_id" => "2"}]} = :sys.get_state(pid)
    end
  end

  describe "QueryServer insert" do
    test "should insert data for the correct coll" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

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

    test "should notify data changed in the widget group correctly" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{\"idx\": 1}")

      # BOTH process in Group 1 should receive the change event
      group1 = Widget.get_widget_group(@env_id, "test", "{}")
      # Group 1 should NOT receive the change event (wrong env_id)
      group2 = Widget.get_widget_group(@env_id + 1, "test", "{}")
      # Group 1 should NOT receive the change event (wrong coll)
      group3 = Widget.get_widget_group(@env_id, "test1", "{}")
      # Group 1 should NOT receive the change event (query does not match)
      group4 = Widget.get_widget_group(@env_id, "test", "{\"aaaa\": 1}")
      # Group 1 should receive the change event (query match)
      group5 = Widget.get_widget_group(@env_id, "test", "{\"idx\": 1}")

      p1 = spawn_pass_process(:a1)
      p1b = spawn_pass_process(:a1b)
      p2 = spawn_pass_process(:a2)
      p3 = spawn_pass_process(:a3)
      p4 = spawn_pass_process(:a4)
      p5 = spawn_pass_process(:a5)

      Swarm.join(group1, p1)
      Swarm.join(group1, p1b)
      Swarm.join(group2, p2)
      Swarm.join(group3, p3)
      Swarm.join(group4, p4)
      Swarm.join(group5, p5)

      Swarm.multi_call(QueryServer.group_name("42"), {:mongo_event, insert_event(1)})

      assert_received {:a1, {:data_changed, [%{"_id" => "1"}]}}
      assert_received {:a1b, {:data_changed, [%{"_id" => "1"}]}}
      refute_received {:a2, _}
      refute_received {:a3, _}
      refute_received {:a4, _}
      assert_received {:a5, {:data_changed, [%{"_id" => "1"}]}}
    end

    test "should NOT insert data for the wrong coll" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(2, "foo")})

      assert %{
               coll: "test",
               data: [%{"_id" => "1"}]
             } = :sys.get_state(pid)
    end

    test "should NOT insert data if the query does not match the new element" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{\"idx\": {\"$lt\": 3}}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

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
    test "should update an older data if doc _id is the same" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, update_event(1, "test", 2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "new_test1", "foo" => "bar"}]
             } = :sys.get_state(pid)
    end

    test "should NOT update an older data if _id is different" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

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
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

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
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{\"name\": \"test1\"}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, update_event(1, "test", 2)})

      assert %{
               coll: "test",
               data: []
             } = :sys.get_state(pid)
    end
  end

  describe "QueryServer replace" do
    test "should replace an older data if _id is the same" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, replace_event(1, "test", 2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "new_test1", "foo" => "bar"}]
             } = :sys.get_state(pid)
    end

    test "should NOT replace an older data if _id is different" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

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
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, replace_event(1, "foo", 2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end

    test "should remove the old data if _id is the same but query does not match anymore" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{\"name\": \"test1\"}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, replace_event(1, "test", 2)})

      assert %{
               coll: "test",
               data: []
             } = :sys.get_state(pid)
    end
  end

  describe "QueryServer delete" do
    test "should delete an older data if _id and coll is the same" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, delete_event(1, "test", 2)})

      assert %{
               coll: "test",
               data: []
             } = :sys.get_state(pid)
    end

    test "should NOT delete an older data if coll is different" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, delete_event(1, "foo", 2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end

    test "should NOT delete an older data if id is different" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, delete_event(2, "test", 2)})

      assert %{
               coll: "test",
               data: [%{"_id" => "1", "name" => "test1"}]
             } = :sys.get_state(pid)
    end
  end

  describe "QueryServer drop coll" do
    test "should stop the genserver when drop the coll" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert Process.alive?(pid)
      assert :ok = GenServer.call(pid, {:mongo_event, drop_event("test")})
      assert not Process.alive?(pid)
    end

    test "should NOT stop the genserver when drop another coll" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert Process.alive?(pid)
      assert :ok = GenServer.call(pid, {:mongo_event, drop_event("foo")})
      assert Process.alive?(pid)
    end
  end

  describe "QueryServer rename coll" do
    test "should rename the coll and still work under a new name" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      name = QueryServer.get_name(@env_id, "test", "{}")
      new_name = QueryServer.get_name(@env_id, "bar", "{}")

      group = Widget.get_widget_group(@env_id, "test", "{}")
      new_group = Widget.get_widget_group(@env_id, "bar", "{}")
      p1 = spawn_pass_process(:p1)
      p2 = spawn_pass_process(:p2)
      Swarm.join(group, p1)
      Swarm.join(new_group, p2)

      [pid] = Swarm.members(QueryServer.group_name("42"))

      timestamp = System.os_time(:microsecond)

      # Register under the correct name, insert is working as expected.
      :ok = GenServer.call(pid, {:mongo_event, insert_event(1, "test", 1, timestamp)})
      assert ^pid = Swarm.whereis_name(name)
      assert_receive {:p1, {:data_changed, [%{"_id" => "1"}]}}

      # Rename the coll, the server should still work the same.
      :ok = GenServer.call(pid, {:mongo_event, rename_event("test", "bar", 2, timestamp + 100)})
      assert :undefined = Swarm.whereis_name(name)
      assert ^pid = Swarm.whereis_name(new_name)
      assert_receive {:p1, {:coll_changed, "bar"}}

      # The notification is sent to the new group
      :ok = GenServer.call(pid, {:mongo_event, insert_event(2, "bar", 3, timestamp + 200)})
      assert_receive {:p2, {:data_changed, [%{"_id" => "1"}, %{"_id" => "2"}]}}
    end

    test "should ignore the rename if namesapce coll is different" do
      :ok = QueryDynSup.ensure_child_started(@env_id, "42", "test", "{}")
      [pid] = Swarm.members(QueryServer.group_name("42"))

      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(1)})
      assert %{coll: "test", data: [%{"_id" => "1"}]} = :sys.get_state(pid)

      assert :ok = GenServer.call(pid, {:mongo_event, rename_event("foo", "bar")})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(2)})
      assert :ok = GenServer.call(pid, {:mongo_event, insert_event(3, "bar")})

      assert %{coll: "test", data: [%{"_id" => "1"}, %{"_id" => "2"}]} = :sys.get_state(pid)
    end
  end
end
