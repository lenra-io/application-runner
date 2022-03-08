defmodule ApplicationRunner.DataReferenceServices do
  @moduledoc false

  alias ApplicationRunner.{Data, DataReferences}

  def create(op), do: Ecto.Multi.new() |> create(op)

  def create(multi, %{refs: refs, ref_by: ref_by}) do
    multi
    |> Ecto.Multi.run(:refs, fn repo, _params ->
      case repo.get(Data, refs) do
        nil ->
          {:error, :data_not_found}

        ref ->
          {:ok, ref}
      end
    end)
    |> Ecto.Multi.run(:refBy, fn repo, _params ->
      case repo.get(Data, ref_by) do
        nil ->
          {:error, :data_not_found}

        ref ->
          {:ok, ref}
      end
    end)
    |> Ecto.Multi.insert(:inserted_reference, fn %{refs: %Data{} = refs, ref_by: %Data{} = ref_by} ->
      DataReferences.new(refs.id, ref_by.id)
    end)
  end
end
