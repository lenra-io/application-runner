defmodule ApplicationRunner.DataReferencesServices do
  @moduledoc false

  alias ApplicationRunner.{DataReferences}

  def create(params), do: Ecto.Multi.new() |> create(params)

  def create(multi, params) do
    multi
    |> Ecto.Multi.insert(:inserted_reference, fn _ ->
      DataReferences.new(params)
    end)
  end
end
