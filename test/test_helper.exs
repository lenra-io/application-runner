Application.load(:application_runner)

for app <- Application.spec(:application_runner, :applications) do
  Application.ensure_all_started(app)
end

Application.ensure_started(:application_runner)

ExUnit.start()
