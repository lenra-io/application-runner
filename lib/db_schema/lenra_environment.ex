defmodule ApplicationRunner.Environment do
  @moduledoc """
    The embedded environement schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ApplicationRunner.Datastore

  embedded_schema do
    has_one(:datastore, Datastore, foreign_key: :environment_id)
    timestamps()
  end

  def embede(environment) do
    %ApplicationRunner.Environment{}
    |> cast(environment, [])
  end
end
