defmodule ApplicationRunner.DataQueryViewServices do
  @moduledoc false
  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.DataQueryView

  def get_one(env_id, datastore_name, data_id) do
    from(
      dv in DataQueryView,
      where:
        dv.environment_id == ^env_id and
          dv.id == ^data_id and
          fragment("data ->> '_datastore'") == ^datastore_name,
      select: dv
    )
  end

  def get_all(env_id, datastore_name) do
    from(
      dv in DataQueryView,
      where:
        dv.environment_id == ^env_id and
          fragment("data ->> '_datastore'") == ^datastore_name,
      select: dv
    )
  end
end
