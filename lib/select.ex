defmodule ApplicationRunner.Select do
  import Ecto.Query, only: [from: 2]

  alias Applicationrunner.{Data, Datastore, Refs}

  @repo Application.compile_env!(:application_runner, :repo)

  def get(app_id, %{"table" => table}) do
    case @repo.all(from(d in Data, select: d)) do
      nil -> {:error, :data_not_found}
      data -> data
    end
  end

  def get(app_id, %{"table" => table, "ids" => ids}) do
    Enum.map(ids, fn id -> @repo.get(Data, id) end)
  end

  def get(app_id, %{"table" => table, "refBy" => ref_by}) do
    Enum.map(ref_by, fn by ->
      @repo.all(
        from(d in Data,
          join: r in assoc(d, :referencer_id),
          where: r == by,
          select: d
        )
      )
    end)
  end

  def get(app_id, %{"table" => table, "refTo" => ref_to}) do
    Enum.map(ref_to, fn to ->
      @repo.all(
        from(d in Data,
          join: r in assoc(d, :referenced_id),
          where: r == to,
          select: d
        )
      )
    end)
  end
end
