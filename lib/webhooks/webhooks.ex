defmodule ApplicationRunner.Webhooks.Webhook do
  @moduledoc """
    The webhook schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Webhooks.Webhook

  @derive {Jason.Encoder, only: [:id, :action, :props]}
  @primary_key {:uuid, :binary_id, autogenerate: true}
  schema "webhooks" do
    has_one(:env, ApplicationRunner.Contract.Environment, foreign_key: :id)

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
    %Webhook{env: env_id}
    |> Webhook.changeset(params)
  end
end
