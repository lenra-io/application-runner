defmodule ApplicationRunner.FakeLenraEnviroonmentTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{
    Environment,
    FakeLenraEnvironment,
    Repo
  }

  test "changeset shoould be valid" do
    changeset =
      %{id: 1}
      |> FakeLenraEnvironment.new()
      |> Repo.insert!()
      |> Map.from_struct()
      |> Environment.embede()

    assert changeset.valid?
  end
end
