defmodule ApplicationRunner.AST.Parser do
  @moduledoc """
    This module parse Json query into an AST tree.
    It takes care of simplifications and organize a tree that is easy to navigate into.
  """
  alias ApplicationRunner.AST.{
    And,
    ArrayValue,
    Contains,
    DataKey,
    Eq,
    Find,
    MeRef,
    NumberValue,
    Query,
    Select,
    StringValue
  }

  def from_json(nil), do: nil

  def from_json(q) do
    parse_query(q, %{})
  end

  defp parse_query(%{"$find" => find}, ctx) do
    %Query{
      find: parse_find(find, ctx),
      select: %Select{clause: nil}
    }
  end

  defp parse_find(find, ctx) do
    %Find{clause: parse_expr(find, ctx)}
  end

  # Map is equivalent to a "$and" clause
  defp parse_expr(clauses, ctx) when is_map(clauses) do
    parse_expr({"$and", Map.to_list(clauses)}, ctx)
  end

  # A key that starts with $ is a function
  defp parse_expr({"$" <> _ = k, val}, ctx) do
    parse_fun({k, val}, ctx)
  end

  # A simple k => v clause
  defp parse_expr({k, v}, ctx) do
    ctx = Map.merge(ctx, %{left: from_k(k, ctx)})
    parse_expr(v, ctx)
  end

  # If there is a left in context, and is not a function, this is a simplified $eq function
  defp parse_expr(value, %{left: _} = ctx) do
    parse_expr({"$eq", value}, ctx)
  end

  # List with eq_value ctx is an ArrayValue
  defp parse_expr(clauses, ctx) when is_list(clauses) do
    %ArrayValue{values: Enum.map(clauses, &parse_expr(&1, ctx))}
  end

  defp parse_expr("@me", _ctx) do
    %MeRef{}
  end

  defp parse_expr(value, _ctx) when is_bitstring(value) do
    %StringValue{value: value}
  end

  defp parse_expr(value, _ctx) when is_number(value) do
    %NumberValue{value: value}
  end

  # Simplification of an "$and" function with only one clause
  defp parse_fun({"$and", [clause]}, ctx) do
    parse_expr(clause, ctx)
  end

  defp parse_fun({"$and", clauses}, ctx) when is_list(clauses) do
    %And{clauses: Enum.map(clauses, &parse_expr(&1, ctx))}
  end

  # Eq function
  defp parse_fun({"$eq", val}, %{left: _} = ctx) do
    {left, ctx} = Map.pop(ctx, :left)
    %Eq{left: left, right: parse_expr(val, ctx)}
  end

  # contains function
  defp parse_fun({"$contains", clauses}, %{left: _} = ctx) when is_list(clauses) do
    {left, ctx} = Map.pop(ctx, :left)
    %Contains{field: left, clauses: Enum.map(clauses, &parse_expr(&1, ctx))}
  end

  defp from_k(key, _ctx) when is_bitstring(key) do
    %DataKey{key_path: String.split(key, ".")}
  end
end
