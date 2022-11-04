defmodule ApplicationRunner.Scheduler do
  @otp_app Application.compile_env(:application_runner, :otp_app)
  use Quantum, otp_app: @otp_app
end
