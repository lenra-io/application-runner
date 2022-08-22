defmodule ApplicationRunner.Session.ChangeEventManager do
  use GenServer

  alias ApplicationRunner.Environment.QueryServer

  def start_link(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    session_id = Keyword.fetch!(opts, :session_id)

    with {:ok, pid} <-
           GenServer.start_link(__MODULE__, opts, name: get_full_name(env_id, session_id)) do
      Swarm.join(get_group(env_id), pid)
      {:ok, pid}
    end
  end

  def get_full_name(env_id, session_id) do
    {:via, :swarm, get_name(env_id, session_id)}
  end

  def get_name(env_id, session_id) do
    {__MODULE__, env_id, session_id}
  end

  def get_group(env_id) do
    {__MODULE__, env_id}
  end

  def init(opts) do
    env_id = Keyword.fetch!(opts, :env_id)
    session_id = Keyword.fetch!(opts, :session_id)
    {:ok, %{env_id: env_id, session_id: session_id}}
  end

  def handle_info({:mongo_event, doc}, %{session_id: session_id} = state) do
    session_id
    |> QueryServer.group_name()
    |> Swarm.multi_call({:mongo_event, doc})
    |> Enum.reduce_while(
      :ok,
      fn
        :ok, _acc -> {:cont, :ok}
        err, _acc -> {:halt, {:error, err}}
      end
    )
    |> case do
      :ok ->
        GenServer.cast({:via, :swarm, {:ui_builder, session_id}}, :rebuild)

      {:error, err} ->
        GenServer.cast({:via, :swarm, {:ui_builder, session_id}}, {:data_error, err})
    end

    {:noreply, state}
  end
end
