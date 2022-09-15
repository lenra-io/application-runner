defmodule ApplicationRunner.Webhooks.Webhook do
  @moduledoc """
    The webhook schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Contract.Environment
  alias ApplicationRunner.Webhooks.Webhook

  @derive {Jason.Encoder, only: [:uuid, :action, :props, :environment_id]}
  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  schema "webhooks" do
    belongs_to(:environment, Environment)

    field(:action, :string)
    field(:props, :map)

    timestamps()
  end

  def changeset(webhook, params \\ %{}) do
    webhook
    |> cast(params, [:action, :props])
    |> validate_required([:action])
    |> foreign_key_constraint(:environment_id)
  end

  def new(env_id, params) do
    %Webhook{environment_id: env_id}
    |> Webhook.changeset(params)
  end
end
