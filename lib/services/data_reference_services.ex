defmodule ApplicationRunner.DataReferencesServices do
  @moduledoc false

  alias ApplicationRunner.DataReferences

  def create(params), do: Ecto.Multi.new() |> create(params)

  def create(multi, params) do
    multi
    |> Ecto.Multi.insert(:inserted_reference, fn _ ->
      DataReferences.new(params)
    end)
  end

  def delete(params), do: Ecto.Multi.new() |> delete(params)

  def delete(multi, %{refs: refs, refBy: refBy}) do
    multi
    |> Ecto.Multi.run(:reference, fn repo, _params ->
      case repo.get_by(DataReferences, refs_id: refs, refBy_id: refBy) do
        nil ->
          {:error, :reference_not_found}

        ref ->
          {:ok, ref}
      end
    end)
    |> Ecto.Multi.delete(:inserted_reference, fn %{reference: %DataReferences{} = reference} ->
      reference
    end)
  end
end
