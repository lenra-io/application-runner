defmodule ApplicationRunner.Ecto.Reference do
  use Ecto.Type
  def type, do: :string

  def cast(reference) when is_reference(reference) do
    {:ok, reference |> :erlang.ref_to_list() |> List.to_string()}
  end

  def cast(_), do: :error

  def load(reference) when is_bitstring(reference) do
    {:ok, String.to_charlist(reference) |> :erlang.list_to_ref()}
  end

  def dump(reference), do: cast(reference)
end
