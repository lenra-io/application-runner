defmodule ApplicationRunner.Crons.Cron do
  @moduledoc """
    The crons schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.{Environment, User}
  alias Crontab.CronExpression.Parser

  @derive {Jason.Encoder,
           only: [
             :id,
             :listener_name,
             :cron_expression,
             :props,
             :should_run_missed_steps,
             :last_run_date,
             :environment_id,
             :user_id
           ]}
  schema "crons" do
    belongs_to(:environment, Environment)
    belongs_to(:user, User)

    field(:listener_name, :string)
    field(:cron_expression, :string)
    field(:props, :map)

    field(:should_run_missed_steps, :boolean, default: false)
    field(:last_run_date, :date)

    timestamps()
  end

  def changeset(webhook, params \\ %{}) do
    webhook
    |> cast(params, [
      :listener_name,
      :cron_expression,
      :props,
      :should_run_missed_steps,
      :last_run_date,
      :user_id
    ])
    |> validate_required([:environment_id, :listener_name, :cron_expression])
    |> validate_change(:cron_expression, fn :cron_expression, cron ->
      case Parser.parse(cron) do
        {:ok, _cron_expr} -> []
        _ -> [cron_expression: "Cron Expression is malformed."]
      end
    end)
    |> foreign_key_constraint(:environment_id)
    |> foreign_key_constraint(:user_id)
  end

  def update(%__MODULE__{} = cron, params) do
    changeset(cron, params)
  end

  def new(env_id, params) do
    %__MODULE__{environment_id: env_id}
    |> __MODULE__.changeset(params)
  end
end
