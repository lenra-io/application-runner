defmodule ApplicationRunner.Webhooks.Webhook do
  @moduledoc """
    The webhook schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.{Environment, User}
  alias ApplicationRunner.Webhooks.Webhook

  @derive {Jason.Encoder, only: [:uuid, :action, :props, :environment_id, :user_id]}
  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  schema "webhooks" do
    belongs_to(:environment, Environment)
    belongs_to(:user, User)

    field(:action, :string)
    field(:props, :map)

    timestamps()
  end

  def changeset(webhook, params \\ %{}) do
    webhook
    |> cast(params, [:action, :props, :user_id])
    |> validate_required([:environment_id, :action])
    |> foreign_key_constraint(:environment_id)
    |> foreign_key_constraint(:user_id)
  end

  def new(env_id, params) do
    %Webhook{environment_id: env_id}
    |> Webhook.changeset(params)
  end
end
