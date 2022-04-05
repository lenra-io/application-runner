defmodule ApplicationRunner.DataQueryView do
  @moduledoc """
    The schema that represent the json data view by the dev.
    This is the table to apply the query on.
  """

  use Ecto.Schema

  @derive {Jason.Encoder, only: [:data]}
  schema "data_query_view" do
    field(:data, :map)
    field(:environment_id, :integer)
  end
end
