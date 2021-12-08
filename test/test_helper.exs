Application.load(:application_runner)

# This start all the dependancy applications needed
for app <- Application.spec(:application_runner, :applications) do
  Application.ensure_all_started(app)
end

ExUnit.start()
