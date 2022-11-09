defmodule ApplicationRunner.Monitor do
  @moduledoc """
  This module is monitoring requests at different places
  ApplicationRunner's monitor executes the following events:
  * `[:ApplicationRunner, :app_session, :start]` - Executed on socket open.
    #### Measurements
      * start_time.
    #### Metadata
      * `:user_id` - The id of the user who executed the action.
      * `:env_id` - The name of the application from which the action was executed.
  * `[:ApplicationRunner, :app_session, :stop]` - Executed after socket closed.
    #### Measurements
      * end_time.
      * `:duration` - The time took by the openfaas action in `:native` unit of time.
  """
  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.Monitor.{
    EnvListenerMesureament,
    SessionListenerMesureament,
    SessionMeasurement
  }

  @repo Application.compile_env(:application_runner, :repo)

  def setup do
    events = [
      [:application_runner, :app_session, :start],
      [:application_runner, :app_session, :stop],
      [:application_runner, :app_listener, :start],
      [:application_runner, :app_listener, :stop]
    ]

    :telemetry.attach_many(
      "application_runner.monitor",
      events,
      &ApplicationRunner.Monitor.handle_event/4,
      nil
    )
  end

  def handle_event([:application_runner, :app_session, :start], measurements, metadata, _config) do
    env_id = Map.get(metadata, :env_id)
    user_id = Map.get(metadata, :user_id)

    @repo.insert(SessionMeasurement.new(env_id, user_id, measurements))
  end

  def handle_event([:application_runner, :app_session, :stop], measurements, metadata, _config) do
    env_id = Map.get(metadata, :env_id)
    user_id = Map.get(metadata, :user_id)

    @repo.one!(
      from(sm in SessionMeasurement,
        where: sm.user_id == ^user_id and sm.environment_id == ^env_id,
        order_by: [desc: sm.inserted_at],
        limit: 1
      )
    )
    |> SessionMeasurement.update(measurements)
    |> @repo.update()
  end

  def handle_event([:application_runner, :app_listener, :start], measurements, metadata, _config) do
    env_id = Map.get(metadata, "env_id")

    Map.get(metadata, "type")
    |> case do
      "session" ->
        user_id = Map.get(metadata, "user_id")

        session_mesureament = get_session_mesureament(env_id, user_id)

        @repo.insert(SessionListenerMesureament.new(session_mesureament.uuid, measurements))

      "env" ->
        @repo.insert(EnvListenerMesureament.new(env_id, measurements))
    end
  end

  def handle_event([:application_runner, :app_listener, :stop], measurements, metadata, _config) do
    env_id = Map.get(metadata, "env_id")

    Map.get(metadata, "type")
    |> case do
      "sessions" ->
        user_id = Map.get(metadata, "user_id")

        session_mesureament = get_session_mesureament(env_id, user_id)

        @repo.one!(
          from(sm in SessionListenerMesureament,
            where: sm.session_mesureament_uuid == ^session_mesureament.uuid,
            order_by: [desc: sm.inserted_at],
            limit: 1
          )
        )
        |> SessionListenerMesureament.update(measurements)
        |> @repo.update()

      "env" ->
        @repo.one!(
          from(em in EnvListenerMesureament,
            where: em.env_id == ^env_id,
            order_by: [desc: em.inserted_at],
            limit: 1
          )
        )
        |> EnvListenerMesureament.update(measurements)
        |> @repo.update()
    end
  end

  defp get_session_mesureament(env_id, user_id) do
    @repo.one!(
      from(sm in SessionMeasurement,
        where: sm.user_id == ^user_id and sm.environment_id == ^env_id,
        order_by: [desc: sm.inserted_at],
        limit: 1
      )
    )
  end
end
