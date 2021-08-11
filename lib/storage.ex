defmodule ApplicationRunner.Storage do
  @moduledoc """
    `ApplicationRunner.Storage` is a GenServer that provide key-value in memory storage
  """
  use GenServer
  require Logger

  @name __MODULE__
  @tables [:final_ui, :listeners, :datastore]

  # GenServer Callbacks

  @impl true
  def init(_) do
    Enum.each(@tables, fn table -> :ets.new(table, [:named_table]) end)
    {:ok, "Tables created"}
  end

  @impl true
  def handle_call({:insert, table, key, data}, _from, state) when table in @tables do
    :ets.insert(table, {key, data})
    {:reply, {:ok, data}, state}
  end

  @impl true
  def handle_call({:get, table, key, default}, _from, state) do
    case :ets.lookup(table, key) do
      [] ->
        {:reply, default, state}

      [{_key, data}] ->
        {:reply, data, state}
    end
  end

  # Client API
  def start_link(_), do: GenServer.start_link(@name, [], name: @name)

  @doc ~S"""
    Insert the `data` in the given `table` in any of `@tables` using the given `key`

    # Examples
      iex> ApplicationRunner.Storage.insert(:final_ui, "test", "val")
      iex> ApplicationRunner.Storage.get(:final_ui, "test")
      "val"

    If the given `table` is not in one of `@tables`, raise an ArgumentError
      iex> ApplicationRunner.Storage.insert(:notexists, "truc", "machin")
      ** (ArgumentError) ETS : Unknown table name notexists
  """
  @spec insert(:final_ui | :listeners | :ui, String.t(), any()) :: {:ok, any()}
  def insert(table, _key, _data) when table not in @tables do
    raise ArgumentError, "ETS : Unknown table name #{table}"
  end

  def insert(table, key, data) when table in @tables do
    GenServer.call(@name, {:insert, table, key, data})
  end

  @doc ~S"""
    Get the data from the given `table` in any of `@tables` for the given `key`

    # Examples
      iex> ApplicationRunner.Storage.insert(:final_ui, "test", "val")
      iex> ApplicationRunner.Storage.get(:final_ui, "test")
      "val"

    If the given key does not exists, return the given `default` value (nil by default)
      iex> ApplicationRunner.Storage.get(:final_ui, "hey", "nope")
      "nope"

      iex> ApplicationRunner.Storage.get(:final_ui, "hey")
      nil

    If the given `table` is not in one of `@tables`, raise an ArgumentError
      iex> ApplicationRunner.Storage.get(:notexists, "truc")
      ** (ArgumentError) ETS : Unknown table name notexists
  """
  def get(table, key, default \\ nil)

  def get(table, _key, _default) when table not in @tables,
    do: raise(ArgumentError, "ETS : Unknown table name #{table}")

  def get(table, key, default) when table in @tables do
    GenServer.call(@name, {:get, table, key, default})
  end

  @doc ~S"""
    Return a data key created with `client_id` and `app_name`
    Each key is uniq for the same arguments

    # Examples
      iex> ApplicationRunner.Storage.generate_final_ui_key(42, "Counter")
      "42:Counter"
  """
  def generate_data_key(client_id, app_name) do
    "#{client_id}:#{app_name}"
  end

  @doc ~S"""
    Return a final_ui key created with `client_id` and `app_name`
    Each key is uniq for the same arguments

    # Examples
      iex> ApplicationRunner.Storage.generate_final_ui_key(42, "Counter")
      "42:Counter"
  """
  def generate_final_ui_key(client_id, app_name) do
    "#{client_id}:#{app_name}"
  end

  @doc ~S"""
    Return a listener key created with `client_id`, `app_name`, `action_code` and `props`.
    Each key is uniq for the same arguments

    # Examples
      iex> ApplicationRunner.Storage.generate_listeners_key("InitData", %{"toto" => "tata"})
      "InitData:{\"toto\":\"tata\"}"
  """
  def generate_listeners_key(action_code, props) do
    "#{action_code}:#{Jason.encode!(props)}"
  end

  @doc ~S"""
    Return a ui key created with `client_id`, `app_name`, `action_code` and `props`.
    Each key is uniq for the same arguments

    # Examples
      iex> ApplicationRunner.Storage.generate_ui_key(42, "Counter", "InitData", %{"toto" => "tata"})
      "42:Counter:InitData:{\"toto\":\"tata\"}"
  """
  def generate_ui_key(client_id, app_name, action_code, props) do
    "#{client_id}:#{app_name}:#{action_code}:#{Jason.encode!(props)}"
  end
end
