defmodule ApplicationRunner.Monitor do
  @moduledoc """
  This module is monitoring requests at different places
  Lenra's monitor executes the following events:
  * `[:lenra, :openfaas_action, :start]` - Executed before an openfaas action.
    #### Measurements
      * No need for any measurement.
    #### Metadata
      * No need for any metadata.
  * `[:lenra, :openfaas_action, :stop]` - Executed after an openfaas action.
    #### Measurements
      * `:duration` - The time took by the openfaas action in `:native` unit of time.
    #### Metadata
      * `:user_id` - The id of the user who executed the action.
      * `:application_name` - The name of the application from which the action was executed.
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
    IO.inspect({:event, measurements, metadata})

    @repo.insert(SessionMeasurement.new(env_id, user_id, measurements)) |> IO.inspect()
  end

  def handle_event([:application_runner, :app_session, :stop], measurements, metadata, _config) do
    env_id = Map.get(metadata, :env_id)
    user_id = Map.get(metadata, :user_id)

    @repo.one!(
      from(sm in SessionMeasurement,
        where: sm.user_id == ^user_id and sm.environment_id == ^env_id,
        order_by: sm.inserted_at,
        limit: 1
      )
    )
    |> Ecto.Changeset.change(measurements)
    |> @repo.update()
  end
end
