defmodule ApplicationRunner.DataReferencesServices do
  @moduledoc false
  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.{Data, Datastore, DataReferences}

  def create(params), do: Ecto.Multi.new() |> create(params)

  def create(multi, params) do
    multi
    |> check_env(params)
    |> Ecto.Multi.insert(:inserted_reference, fn _ ->
      DataReferences.new(params)
    end)
  end

  defp check_env(multi, %{refs_id: refs, refBy_id: refBy}) do
    multi
    |> Ecto.Multi.run(:data_reference, fn repo, _params ->
      refs_env_id =
        repo
        |> get_env_id(refs)

      refBy_env_id =
        repo
        |> get_env_id(refBy)

      case refs_env_id == refBy_env_id do
        true ->
          {:ok, %{refs_id: refs, refBy_id: refBy}}

        false ->
          {:error, :reference_not_found}
      end
    end)
  end

  defp check_env(multi, _params), do: multi

  defp get_env_id(repo, reference) do
    repo.one(
      from(
        ds in Datastore,
        join: d in Data,
        on: d.datastore_id == ds.id,
        where: d.id == ^reference,
        select: ds.environment_id
      )
    )
  end

  def delete(params), do: Ecto.Multi.new() |> delete(params)

  def delete(multi, %{refs_id: refs, refBy_id: refBy}) do
    multi
    |> Ecto.Multi.run(:reference, fn repo, _params ->
      case repo.get_by(DataReferences, refs_id: refs, refBy_id: refBy) do
        nil ->
          {:error, :reference_not_found}

        ref ->
          {:ok, ref}
      end
    end)
    |> Ecto.Multi.delete(:deleted_reference, fn %{reference: %DataReferences{} = reference} ->
      reference
    end)
  end

  def delete(multi, _params) do
    multi
    |> Ecto.Multi.run(:reference, fn _repo, _params ->
      {:error, :json_format_invalid}
    end)
  end
end
