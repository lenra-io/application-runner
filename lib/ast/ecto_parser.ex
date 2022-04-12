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
    MeRef,
    NumberValue,
    Query,
    StringValue
  }

  import Ecto.Query

  def to_ecto(%Query{find: find, select: _select}, env_id, user_data_id) do
    where_clauses = parse_expr(find, %{user_data_id: user_data_id})

    DataQueryView
    |> where([d], d.environment_id == ^env_id)
    |> where([d], ^where_clauses)
  end

  defp parse_expr(%Find{clause: clause}, ctx) do
    parse_expr(clause, ctx)
  end

  defp parse_expr(%And{clauses: []}, _ctx) do
    dynamic([p], true)
  end

  defp parse_expr(%And{clauses: clauses}, ctx) do
    clauses
    |> Enum.map(&parse_expr(&1, ctx))
    |> Enum.reduce(fn acc, expr ->
      dynamic([d], ^acc and ^expr)
    end)
  end

  defp parse_expr(%Eq{left: left, right: right}, ctx) do
    parsed_left = parse_expr(left, ctx)
    parsed_right = parse_expr(right, ctx)
    dynamic([d], ^parsed_left == ^parsed_right)
  end

  defp parse_expr(%DataKey{key_path: key_path}, _ctx) do
    dynamic([d], fragment("? #> ?", d.data, ^key_path))
  end

  defp parse_expr(%StringValue{value: value}, _ctx) do
    value
  end

  defp parse_expr(%MeRef{}, %{user_data_id: user_data_id}) do
    user_data_id
  end

  defp parse_expr(%ArrayValue{values: values}, ctx) do
    Enum.map(values, fn value -> parse_expr(value, ctx) end)
  end

  defp parse_expr(%NumberValue{value: value}, _ctx) do
    value
  end
end
