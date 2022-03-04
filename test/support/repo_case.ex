defmodule ApplicationRunner.RepoCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias ApplicationRunner.Repo

      import Ecto
      import Ecto.Query
      import ApplicationRunner.RepoCase

      # and any other stuff
    end
  end
end
