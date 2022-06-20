Application.load(:application_runner)

# This start all the dependancy applications needed
for app <- Application.spec(:application_runner, :applications) do
  IO.inspect(app)
  Application.ensure_all_started(app)
end

ExUnit.start()

ApplicationRunner.Repo.start_link()
Mix.Tasks.Ecto.Migrate.run([])
Ecto.Adapters.SQL.Sandbox.mode(ApplicationRunner.Repo, :manual)
