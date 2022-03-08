defmodule ApplicationRunner.DataReferencesServices do
  @moduledoc false

  alias ApplicationRunner.{Data, DataReferences}

  def create(op), do: Ecto.Multi.new() |> create(op)

  def create(multi, %{refs: refs, refBy: refBy}) do
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
      case repo.get(Data, refBy) do
        nil ->
          {:error, :data_not_found}

        ref ->
          {:ok, ref}
      end
    end)
    |> Ecto.Multi.insert(:inserted_reference, fn %{refs: %Data{} = refs, refBy: %Data{} = ref_by} ->
      DataReferences.new(refs.id, ref_by.id)
    end)
  end

  def create(multi, _invalid_json) do
    multi
    |> Ecto.Multi.run(:reference, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end
end
