defmodule ApplicationRunner.Environment.ChangeStream do
  use GenServer

  alias ApplicationRunner.Environment.MongoInstance
  alias ApplicationRunner.Session.ChangeEventManager

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    GenServer.start_link(__MODULE__, opts, name: get_full_name(env_id))
  end

  def get_full_name(env_id) do
    {:via, :swarm, get_name(env_id)}
  end

  def get_name(env_id) do
    {__MODULE__, env_id}
  end

  def init(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    cs_pid = spawn(fn -> start_change_stream(env_id) end)

    state = %{env_id: env_id, cs_pid: cs_pid}
    {:ok, state}
  end

  def handle_cast({:token_event, _token}, state) do
    {:noreply, state}
  end

  def handle_cast({:mongo_event, doc}, %{env_id: env_id} = state) do
    Swarm.publish(ChangeEventManager.get_group(env_id), {:mongo_event, doc})
    {:noreply, state}
  end

  defp start_change_stream(env_id) do
    mongo_name = MongoInstance.get_full_name(env_id)
    cs_name = get_full_name(env_id)

    cursor =
      Mongo.watch_db(
        mongo_name,
        [],
        fn token ->
          GenServer.cast(cs_name, {:token_event, token})
        end,
        full_document: true
      )

    cursor
    |> Enum.each(fn doc ->
      GenServer.cast(cs_name, {:mongo_event, doc})
    end)
  end
end
