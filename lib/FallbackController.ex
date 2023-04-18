defmodule ApplicationRunner.FallbackController do
  use LenraCommonWeb.FallbackController,
    errors_modules: [
      {ApplicationRunner.Errors.BusinessError, 400},
      {ApplicationRunner.Errors.TechnicalError, 500}
    ]
end
