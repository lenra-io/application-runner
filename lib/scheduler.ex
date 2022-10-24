defmodule ApplicationRunner.Scheduler do
  use Quantum, otp_app: Application.compile_env(:application_runner, ApplicationRunner.Scheduler)[:otp_app]
end
