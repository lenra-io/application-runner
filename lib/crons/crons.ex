defmodule ApplicationRunner.Crons.Cron do
  @moduledoc """
    The crons schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.{Environment, User}
  alias Crontab.CronExpression.Parser

  @derive {Jason.Encoder, only: [:id, :listener_name, :cron, :props, :environment_id, :user_id]}
  schema "crons" do
    belongs_to(:environment, Environment)
    belongs_to(:user, User)

    field(:listener_name, :string)
    field(:cron, :string)
    field(:props, :map)

    timestamps()
  end

  def changeset(webhook, params \\ %{}) do
    webhook
    |> cast(params, [:listener_name, :cron, :props, :user_id])
    |> validate_required([:environment_id, :listener_name, :cron])
    |> validate_change(:cron, fn :cron, cron ->
      case Parser.parse(cron) do
        {:ok, _cron_expr} -> []
        _ -> [cron: "Cron Expression is malformed."]
      end
    end)
    |> foreign_key_constraint(:environment_id)
    |> foreign_key_constraint(:user_id)
  end

  def new(env_id, params) do
    %__MODULE__{environment_id: env_id}
    |> __MODULE__.changeset(params)
  end
end
