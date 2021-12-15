alias ApplicationRunner.{Repo, FakeLenraApplication, Datastore, Data}
#Mix.Tasks.Ecto.Create.run([])
#Mix.Tasks.Ecto.Migrate.run([])
#Ecto.Migrator.run(Repo, :up, [])
Repo.insert(FakeLenraApplication.new(1))
