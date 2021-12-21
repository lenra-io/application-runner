alias ApplicationRunner.{Repo, FakeLenraApplication, Datastore, Data, Query}
ApplicationRunner.Repo.start_link()
Mix.Tasks.Ecto.Migrate.run([])
