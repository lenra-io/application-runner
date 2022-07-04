defmodule ApplicationRunner.FakeLenraEnvironmentTest do
  @moduledoc false

  use ApplicationRunner.RepoCase

  alias ApplicationRunner.{
    FakeLenraEnvironment,
    Repo
  }

  alias ApplicationRunner.Lenra.Environment

  test "get on embeded schema should return same user" do
    user =
      %{email: "test@test.te"}
      |> FakeLenraEnvironment.new()
      |> Repo.insert!()

    embed_user = Repo.get!(Environment, user.id)

    assert user.id == embed_user.id
  end

  test "embed schema with valid user should return user" do
    user =
      %{}
      |> FakeLenraEnvironment.new()
      |> Repo.insert!()
      |> Environment.embed()

    assert is_struct(user, Environment)
  end

  test "embed schema with invalid user should return error" do
    user =
      %{truc: "test"}
      |> Environment.embed()

    assert is_struct(user, Ecto.Changeset)
    assert not user.valid?
  end
end
