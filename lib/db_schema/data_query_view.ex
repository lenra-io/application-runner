defmodule ApplicationRunner.DataQueryView do
  @moduledoc """
    The data schema.
  """

  use Ecto.Schema

  @derive {Jason.Encoder, only: [:data]}
  schema "data_query_view" do
    field(:data, :map)
    field(:environment_id, :integer)
  end
end
