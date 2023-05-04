defmodule ApplicationRunner.ApplicationServices do
  @moduledoc """
    The service that manages calls to an Openfaas action with `run_action/3`
  """
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.Guardian.AppGuardian
  alias ApplicationRunner.Telemetry

  require Logger

  defp get_http_context do
    base_url = Application.fetch_env!(:application_runner, :faas_url)
    auth = Application.fetch_env!(:application_runner, :faas_auth)

    headers = [{"Authorization", auth}]
    Logger.debug("Get http context: #{inspect({base_url, headers})}")
    {base_url, headers}
  end

  @doc """
    Run a HTTP POST request with needed headers and body to call an Openfaas Action and decode the response body.

    Returns `:ok` if the HTTP Post succeed
    Returns `{:error, reason}` if the HTTP Post fail
  """
  @spec run_listener(String.t(), String.t(), map(), map(), String.t()) ::
          :ok | {:error, any()}
  def run_listener(
        function_name,
        action,
        props,
        event,
        token
      ) do
    {base_url, base_headers} = get_http_context()

    url = "#{base_url}/function/#{function_name}"

    headers = [
      {"Content-Type", "application/json"} | base_headers
    ]

    body =
      Jason.encode!(%{
        action: action,
        props: props,
        event: event,
        api: %{url: Application.fetch_env!(:application_runner, :url), token: token}
      })

    Logger.debug("Call to Openfaas : #{function_name}")

    Logger.debug("Run app #{function_name} with action #{action}")

    peeked_token = AppGuardian.peek(token)
    start_time = Telemetry.start(:app_listener, peeked_token.claims)

    res =
      Finch.build(:post, url, headers, body)
      |> Finch.request(AppHttp,
        receive_timeout: Application.fetch_env!(:application_runner, :listeners_timeout)
      )
      |> response(:listener)

    Logger.debug("response: #{inspect(res)}")
    Telemetry.stop(:app_listener, start_time, peeked_token.claims)

    res
  end

  @spec fetch_view(String.t(), String.t(), map(), map(), map()) ::
          {:ok, map()} | {:error, any()}
  def fetch_view(
        function_name,
        view_name,
        data,
        props,
        context
      ) do
    {base_url, base_headers} = get_http_context()

    url = "#{base_url}/function/#{function_name}"
    headers = [{"Content-Type", "application/json"} | base_headers]
    body = Jason.encode!(%{view: view_name, data: data, props: props, context: context})

    IO.inspect("APPLICATION SERVICES context")
    IO.inspect(context)

    Logger.debug("Fetch application view \n#{url} : \n#{body}")

    Finch.build(:post, url, headers, body)
    |> Finch.request(AppHttp,
      receive_timeout: Application.fetch_env!(:application_runner, :view_timeout)
    )
    |> response(:view)
    |> case do
      {:ok, %{"view" => view}} ->
        Logger.debug("Got view #{inspect(view)}")

        {:ok, view}

      err ->
        err
    end
  end

  @spec fetch_manifest(String.t()) :: {:ok, map()} | {:error, any()}
  def fetch_manifest(function_name) do
    {base_url, base_headers} = get_http_context()

    url = "#{base_url}/function/#{function_name}"
    headers = [{"Content-Type", "application/json"} | base_headers]

    Logger.debug("Fetch application manifest \n#{url} : \n#{function_name}")

    Finch.build(:post, url, headers)
    |> Finch.request(AppHttp,
      receive_timeout: Application.fetch_env!(:application_runner, :manifest_timeout)
    )
    |> response(:manifest)
    |> case do
      {:ok, %{"manifest" => manifest}} ->
        Logger.debug("Got manifest : #{inspect(manifest)}")
        {:ok, manifest}

      err ->
        Logger.error("Error while getting manifest : #{inspect(err)}")
        err
    end
  end

  @doc """
  Gets a resource from an app using a stream.

  Returns an `Enum`.
  """
  @spec get_app_resource_stream(String.t(), String.t()) :: {:ok, term()} | {:error, Exception.t()}
  def get_app_resource_stream(function_name, resource) do
    {base_url, base_headers} = get_http_context()

    url = "#{base_url}/function/#{function_name}"

    headers = [{"Content-Type", "application/json"} | base_headers]
    body = Jason.encode!(%{resource: resource})

    Finch.build(:post, url, headers, body)
    |> Finch.stream(AppHttp, [], fn
      chunk, acc -> acc ++ [chunk]
    end)
    |> response(:resource)
  end

  def deploy_app(image_name, function_name) do
    {base_url, headers} = get_http_context()

    url = "#{base_url}/system/functions"

    body =
      Jason.encode!(%{
        "image" => image_name,
        "service" => function_name,
        "secrets" => Application.fetch_env!(:lenra, :faas_secrets),
        "limits" => %{
          "memory" => "256Mi",
          "cpu" => "100m"
        },
        "requests" => %{
          "memory" => "128Mi",
          "cpu" => "50m"
        }
      })

    Logger.debug("Deploy Openfaas application \n#{url} : \n#{body}")

    Finch.build(
      :post,
      url,
      headers,
      body
    )
    |> Finch.request(AppHttp, receive_timeout: 1000)
    |> response(:deploy_app)
  end

  defp response({:ok, acc}, :resource) do
    {:ok, acc}
  end

  defp response({:ok, %Finch.Response{status: 200, body: body}}, key)
       when key in [:manifest, :view] do
    {:ok, Jason.decode!(body)}
  end

  defp response({:ok, %Finch.Response{status: 200}}, :listener) do
    :ok
  end

  defp response({:ok, %Finch.Response{status: status_code}}, :deploy_app)
       when status_code in [200, 202] do
    {:ok, status_code}
  end

  defp response({:error, %Mint.TransportError{reason: reason}}, _action) do
    Telemetry.event(
      :alert,
      %{},
      TechnicalError.openfaas_not_reachable(reason)
    )

    TechnicalError.openfaas_not_reachable_tuple()
  end

  defp response(
         {:ok, %Finch.Response{status: status_code, body: body}},
         _action
       )
       when status_code not in [200, 202] do
    case status_code do
      400 ->
        Telemetry.event(:alert, %{}, TechnicalError.bad_request(body))
        TechnicalError.bad_request_tuple(body)

      404 ->
        Logger.error(TechnicalError.error_404(body))
        TechnicalError.error_404_tuple(body)

      500 ->
        Telemetry.event(:alert, %{}, TechnicalError.error_500(body))
        TechnicalError.error_500_tuple(body)

      504 ->
        Logger.error(TechnicalError.timeout(body))
        TechnicalError.timeout_tuple(body)

      err ->
        # maybe alert ?
        Logger.critical(TechnicalError.unknown_error(err))
        TechnicalError.unknown_error_tuple(body)
    end
  end
end
