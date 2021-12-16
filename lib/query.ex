defmodule ApplicationRunner.Query do
  @moduledoc """

  """
  alias ApplicationRunner.{Data, Datastore, Refs}

  @repo Application.compile_env!(:application_runner, :repo)
  # @application Application.compile_env!(:application_runner, :lenra_application_schema)

  def handle_insert(app_id, [lists]) do
    Enum.map(lists, fn list -> insert(app_id, list) end)
  end

  def handle_insert(app_id, req) do
    insert(app_id, req)
  end

  defp handle_refs(datastore_id, data, refBy, refTo) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_datastore, Data.new(datastore_id, data))
    |> Ecto.Multi.run(:inserted_refs, fn _, %{inserted_datastore: %Data{} = data} ->
      case refBy != nil do
        true ->
          inserted_refs = Enum.map(refBy, fn by -> @repo.insert(Refs.new(by, data.id)) end)
          {:ok, inserted_refs}

        false ->
          case refTo != nil do
            true ->
              inserted_refs = Enum.map(refTo, fn to -> @repo.insert(Refs.new(data.id, to)) end)
              {:ok, inserted_refs}

            false ->
              {:error, :json_ref_format_error}
          end
      end
    end)
    |> @repo.transaction()
  end

  def insert(app_id, %{"table" => table, "data" => data, "refBy" => refBy}) do
    datastore = @repo.get_by(Datastore, name: table, application_id: app_id)

    case datastore != nil do
      true -> handle_refs(datastore.id, data, refBy, nil)
      false -> {:error, :datastore_not_found}
    end
  end

  def insert(app_id, %{"table" => table, "data" => data, "refTo" => refTo}) do
    datastore = @repo.get_by(Datastore, name: table, application_id: app_id)

    case datastore != nil do
      true -> handle_refs(datastore.id, data, nil, refTo)
      false -> {:error, :datastore_not_found}
    end
  end

  def insert(app_id, %{"table" => table, "data" => data}) do
    datastore = @repo.get_by(Datastore, name: table, application_id: app_id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:inserted_datastore, Data.new(datastore.id, data))
    |> @repo.transaction()
  end

  def insert(_id, %{"refBy" => refBy, "refTo" => refTo}) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:inserted_refs, fn _, _ ->
      Enum.map(refBy, fn by -> Enum.map(refTo, fn to -> @repo.insert(Refs.new(by, to)) end) end)
    end)
    |> @repo.transaction()
  end

  def insert(_action, _req) do
    {:error, :json_format_error}
  end

  def update(%{"id" => id, "data" => changes}) do
    @repo.get(Data, id)
    |> Ecto.Changeset.change(changes)
    |> @repo.update()
  end

  def delete(%{"id" => id}) do
    data =
      @repo.get(Data, id)
      |> @repo.preload([:referencer, :referenced])

    Enum.map(data.referencer, fn ref -> @repo.delete(ref) end)
    Enum.map(data.referenced, fn ref -> @repo.delete(ref) end)

    @repo.delete(data)
  end
end
