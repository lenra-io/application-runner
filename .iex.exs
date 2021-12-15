alias ApplicationRunner.{Repo, FakeLenraApplication, Datastore, Data}
Mix.Tasks.Ecto.Migrate.run([])
Repo.insert(FakeLenraApplication.new(1))
