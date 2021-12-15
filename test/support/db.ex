defmodule ApplicationRunner.DB do
  use GenServer

  alias ApplicationRunner.{Repo}

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, conn} = Exqlite.Sqlite3.open(":memory:")

    qry = """
    CREATE TABLE applications (
      id INTEGER PRIMARY KEY NOT NULL,
      inserted_at TEXT,
      updated_at TEXT
    );
    """

    res = Exqlite.Sqlite3.execute(conn, qry)
    IO.puts(inspect(res))
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, "insert into applications (id) values (?1)")
    :ok = Exqlite.Sqlite3.bind(conn, statement, [1])
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, "select id from applications")
    # {:row, res} = Exqlite.Sqlite3.step(conn, statement)
    # IO.puts(inspect(res))
    :done = Exqlite.Sqlite3.step(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    # Repo.all(ApplicationRunner.FakeLenraApplication)

    # Ecto.Adapters.SQLite3.dump_versions([])

    {:ok, state}
  end
end
