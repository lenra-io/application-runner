defmodule ApplicationRunner.FakeLenraUserTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{
    FakeLenraUser,
    Repo
  }

  alias ApplicationRunner.Lenra.User

  test "get on embeded schema should return same user" do
    user =
      %{email: "test@test.te"}
      |> FakeLenraUser.new()
      |> Repo.insert!()

    embed_user = Repo.get!(User, user.id)

    assert user.id == embed_user.id
    assert user.email == embed_user.email
  end

  test "embed schema with valid user should return user" do
    user =
      %{email: "test@test.te"}
      |> FakeLenraUser.new()
      |> Repo.insert!()
      |> User.embed()

    assert is_struct(user, User)
  end

  test "embed schema with invalid user should return error" do
    user =
      %{truc: "test@test.te"}
      |> User.embed()

    assert is_struct(user, Ecto.Changeset)
    assert not user.valid?
  end
end
