Application.load(:application_runner)

for app <- Application.spec(:application_runner, :applications) do
  Application.ensure_all_started(app)
end

ApplicationRunner.Repo.start_link()
Mix.Tasks.Ecto.Migrate.run([])
Ecto.Adapters.SQL.Sandbox.mode(ApplicationRunner.Repo, :auto)

Application.ensure_started(:application_runner)

ExUnit.start()
