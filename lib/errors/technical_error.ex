defmodule ApplicationRunner.Errors.TechnicalError do
  @moduledoc """
    Lenra.Errors.TechnicalError handles technical errors for the Lenra app.
    This module uses LenraCommon.Errors.TechnicalError
  """

  use LenraCommon.Errors.ErrorGenerator,
    module: LenraCommon.Errors.TechnicalError,
    inherit: true,
    errors: [
      {:reference_not_found, "Reference not found"},
      {:datastore_not_found, "Datastore cannot be found"},
      {:data_not_found, "Data cannot be found"},
      {:widget_not_found, "No Widget found in app manifest."},
      {:manifest_not_found, "Manifest not found"},
      {:openfaas_not_reachable, "Openfaas could not be reached."},
      {:timeout, "Timeout"},
      {:listener_not_found, "Listener not found"},
      {:mongo_data_fetch_error, "Could not fetch data from mongo."}
    ]
end
