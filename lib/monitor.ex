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

  alias ApplicationRunner.Monitor.SessionMeasurement

  @repo Application.compile_env(:application_runner, :repo)

  def setup do
    events = [
      [:application_runner, :app_session, :start],
      [:application_runner, :app_session, :stop]
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
end
