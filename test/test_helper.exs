Application.load(:application_runner)

# This start all the dependancy applications needed
for app <- Application.spec(:application_runner, :applications) do
  Application.ensure_all_started(app)
end

ApplicationRunner.ApplicationRunnerAdapter.start_link([])

ExUnit.start()

ApplicationRunner.Repo.start_link()
Mix.Tasks.Ecto.Migrate.run([])
