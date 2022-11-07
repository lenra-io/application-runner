Application.load(:application_runner)

ApplicationRunner.Repo.start_link()
Mix.Tasks.Ecto.Migrate.run([])
Ecto.Adapters.SQL.Sandbox.mode(ApplicationRunner.Repo, :manual)

# This start all the dependancy applications needed
for app <- Application.spec(:application_runner, :applications) do
  Application.ensure_all_started(app)
end

ExUnit.start()
