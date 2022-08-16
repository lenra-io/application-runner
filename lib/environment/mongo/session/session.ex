defmodule ApplicationRunner.Environment.Mongo.Session do
  use GenServer

  @env Application.compile_env!(:application_runner, :env)
  @inactivity_timeout 1000 * 60 * 10

  def start_link(opts) do
    session_state = Keyword.fetch!(opts, :session_state)
    session_id = Map.fetch!(session_state, :session_id)

    GenServer.start_link(__MODULE__, opts, name: {:global, {:mongo_session, session_id}})
  end

  def init(opts) do
    session_state = Keyword.fetch!(opts, :session_state)
    env_id = Map.fetch!(session_state, :env_id)

    case Mongo.Session.start_session(@env <> "_#{env_id}", :write, []) do
      {:ok, session} ->
        state = %{session: session}
        {:ok, state, @inactivity_timeout}

      error ->
        raise error
    end
  end

  @impl true
  def handle_call(:stop, _from, state) do
    session = Keyword.fetch!(state, :session)
    Mongo.Session.end_session(session)
    {:reply, :ok, state}
  end
end
