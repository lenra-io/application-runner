defmodule ApplicationRunner.Notifications.Notif do
  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Notifications.Notif

  embedded_schema do
    field(:message, :string)
    field(:title, :string)
    field(:priority, Ecto.Enum, values: [min: 1, low: 2, normal: 3, high: 4, max: 5])
    field(:tags, :string)
    field(:attach, :string)
    field(:actions, :string)
    field(:email, :string)
    field(:click, :string)
    field(:at, :string)
    field(:to, {:array, :string})
  end

  def changeset(notif, params \\ %{}) do
    notif
    |> cast(params, [
      :message,
      :title,
      :priority,
      :tags,
      :attach,
      :actions,
      :email,
      :click,
      :at,
      :to
    ])
    |> validate_required([:message, :to])
  end

  def new(params) do
    changeset(%Notif{}, params)
  end
end
