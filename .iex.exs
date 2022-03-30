alias ApplicationRunner.AST.{Parser, EctoParser}
alias ApplicationRunner.{
  FakeLenraUser,
  Repo,
  FakeLenraEnvironment,
  DataServices,
  DatastoreServices,
  UserDataServices,
  DataReferencesServices
}

Application.ensure_all_started(:postgrex)

ApplicationRunner.Repo.start_link()

populate = fn ->
  FakeLenraUser.new() |> Repo.insert
  FakeLenraEnvironment.new() |> Repo.insert

  DatastoreServices.create(1, %{"name" => "userData"}) |> Repo.transaction
  DatastoreServices.create(1, %{"name" => "todoList"}) |> Repo.transaction
  DatastoreServices.create(1, %{"name" => "todos"}) |> Repo.transaction
  # 1
  DataServices.create(1, %{"datastore" => "userData", "data" => %{"score" => 42}}) |> Repo.transaction
  UserDataServices.create(%{user_id: 1, data_id: 1}) |> Repo.transaction
  # 2
  DataServices.create(1, %{
    "datastore" => "todoList",
    "data" => %{"name" => "favorites"},
    "refBy" => [1]
  })|> Repo.transaction
   # 3
   DataServices.create(1, %{
    "datastore" => "todoList",
    "data" => %{"name" => "not fav"},
    "refBy" => [1]
  })|> Repo.transaction
  # 4
  DataServices.create(1, %{
    "datastore" => "todos",
    "data" => %{"title" => "Faire la vaisselle"},
    "refBy" => [2]
  })|> Repo.transaction
  # 5
  DataServices.create(1, %{
    "datastore" => "todos",
    "data" => %{"title" => "Faire la cuisine"},
    "refBy" => [2]
  })|> Repo.transaction
  # 6
  DataServices.create(1, %{
    "datastore" => "todos",
    "data" => %{"title" => "Faire le ménage"},
    "refBy" => [3]
  })|> Repo.transaction
end
