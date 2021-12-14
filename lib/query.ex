defmodule ApplicationRunner.Query do
  @moduledoc """

  """
  alias ApplicationRunner.{Data, Datastore, Refs}

  @repo Application.compile_env!(:application_runner, :repo)
  @application Application.compile_env!(:application_runner, :lenra_application_schema)

  def handle_insert(action, [lists]) do
    Enum.map(lists, fn list -> insert(action, list) end)
  end

  def handle_insert(action, req) do
    insert(action, req)
  end

  def insert(app_id, %{"table" => table, "data" => data, "refBy" => refBy}) do
    datastore = @repo.get_by(Datastore, name: table, application_id: app_id)
    {:ok, inserted_data} = @repo.insert(Data.new(datastore.id, data))

    Enum.map(refBy, fn by -> @repo.insert(Refs.new(by, inserted_data.id)) end)
  end

  def insert(app_id, %{"table" => table, "data" => data, "refTo" => refTo}) do
    with {:ok, inserted_data} <-
           insert_data(app_id, table, data) do
      Enum.map(refTo, fn to -> @repo.insert(Refs.new(inserted_data.id, to)) end)
    end
  end

  def insert(app_id, %{"table" => table, "data" => data}) do
    datastore = @repo.get_by(Datastore, name: table, application_id: app_id)
    @repo.insert(Data.new(datastore.id, data))
  end

  defp insert_data(app_id, table, data) do
    datastore = @repo.get_by(Datastore, name: table, application_id: app_id)
    @repo.insert(Data.new(datastore.id, data))
  end

  def insert(_action, %{"refBy" => refBy, "refTo" => refTo}) do
    Enum.map(refBy, fn by -> Enum.map(refTo, fn to -> @repo.insert(Refs.new(by, to)) end) end)
  end

  def insert(_action, _req) do
    raise "insert format error"
  end

  def update(%{"id" => id, "data" => changes}) do
    @repo.get(Data, id)
    |> Ecto.Changeset.change(changes)
    |> @repo.update()
  end

  def delete(%{"id" => id}) do
    data = @repo.get(Data, id)

    data =
      data
      |> @repo.preload([:referencer, :referenced])

    IO.puts(inspect(data))
    Enum.map(data.referencer, fn ref -> @repo.delete(ref) end)
    Enum.map(data.referenced, fn ref -> @repo.delete(ref) end)

    @repo.delete(data)
  end
end
