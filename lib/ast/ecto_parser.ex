defmodule ApplicationRunner.AST.EctoParser do
  alias ApplicationRunner.{DataQueryView}

  alias ApplicationRunner.AST.{
    And,
    ArrayValue,
    DataKey,
    Eq,
    Find,
    NumberValue,
    Query,
    Select,
    StringValue
  }

  import Ecto.Query

  def to_ecto(%Query{find: find, select: _select}) do
    where_clauses = parse_expr(find)

    DataQueryView
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

  defp parse_expr(%DataKey{key: key}) do
    dynamic([d], fragment("data ->> ?", ^key))
  end

  defp parse_expr(%StringValue{value: value}) do
    value
  end

  defp parse_expr(%NumberValue{value: value}) do
    value |> Integer.to_string()
  end
end
