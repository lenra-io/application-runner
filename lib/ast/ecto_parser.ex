defmodule ApplicationRunner.AST.EctoParser do
  @moduledoc """
    This module parse AST tree into Ecto query.
  """
  alias ApplicationRunner.DataQueryView

  alias ApplicationRunner.AST.{
    And,
    ArrayValue,
    DataKey,
    Eq,
    Find,
    NumberValue,
    Query,
    StringValue,
    MeRef
  }

  import Ecto.Query

  def to_ecto(%Query{find: find, select: _select}, env_id) do
    where_clauses = parse_expr(find)

    DataQueryView
    |> where([d], d.environment_id == ^env_id)
    |> where([d], ^where_clauses)
  end

  defp parse_expr(%Find{clause: clause}) do
    parse_expr(clause)
  end

  defp parse_expr(%And{clauses: []}) do
    dynamic([p], true)
  end

  defp parse_expr(%And{clauses: clauses}) do
    clauses
    |> Enum.map(&parse_expr(&1))
    |> Enum.reduce(fn acc, expr ->
      dynamic([d], ^acc and ^expr)
    end)
  end

  defp parse_expr(%Eq{left: left, right: right}) do
    parsed_left = parse_expr(left)
    parsed_right = parse_expr(right)
    dynamic([d], ^parsed_left == ^parsed_right)
  end

  defp parse_expr(%DataKey{key_path: key_path}) do
    dynamic([d], fragment("? #> ?", d.data, ^key_path))
  end

  defp parse_expr(%StringValue{value: value}) do
    value
  end

  defp parse_expr(%MeRef{id: id}) do
    id
  end

  defp parse_expr(%ArrayValue{values: values}) do
    Enum.map(values, fn value -> parse_expr(value) end)
  end

  defp parse_expr(%NumberValue{value: value}) do
    value
  end
end
