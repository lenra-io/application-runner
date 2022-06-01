defmodule ApplicationRunner.FakeLenraUserTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{
    FakeLenraUser,
    Repo,
    User
  }

  test "changeset shoould be valid" do
    changeset =
      %{email: "test@test.te"}
      |> FakeLenraUser.new()
      |> Repo.insert!()
      |> Map.from_struct()
      |> User.embede()

    assert changeset.valid?
  end
end
