defmodule ApplicationRunner.ApplicationServices do
  @moduledoc """
    The service that manages calls to an Openfaas action with `run_action/3`
  """

  alias ApplicationRunner.Errors.TechnicalError
  require Logger

  defp get_http_context do
    base_url = Application.fetch_env!(:application_runner, :faas_url)
    auth = Application.fetch_env!(:application_runner, :faas_auth)

    headers = [{"Authorization", auth}]
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

    Finch.build(:post, url, headers, body)
    |> Finch.request(AppHttp, receive_timeout: 0)
    |> response(:listener)
  end

  @spec fetch_widget(String.t(), String.t(), map(), map(), map()) ::
          {:ok, map()} | {:error, any()}
  def fetch_widget(
        function_name,
        widget_name,
        data,
        props,
        context
      ) do
    {base_url, base_headers} = get_http_context()

    url = "#{base_url}/function/#{function_name}"
    headers = [{"Content-Type", "application/json"} | base_headers]
    body = Jason.encode!(%{widget: widget_name, data: data, props: props, context: context})

    Finch.build(:post, url, headers, body)
    |> Finch.request(AppHttp, receive_timeout: 1000)
    |> response(:widget)
    |> case do
      {:ok, %{"widget" => widget}} ->
        {:ok, widget}

      err ->
        err
    end
  end

  @spec fetch_manifest(String.t()) :: {:ok, map()} | {:error, any()}
  def fetch_manifest(function_name) do
    {base_url, base_headers} = get_http_context()

    url = "#{base_url}/function/#{function_name}"
    headers = [{"Content-Type", "application/json"} | base_headers]

    Finch.build(:post, url, headers)
    |> Finch.request(AppHttp, receive_timeout: 1000)
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
        },
        upstream_timeout: "300s"
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
       when key in [:manifest, :widget] do
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
    Logger.error("Openfaas could not be reached. It should not happen. \n\t\t reason: #{reason}")
    TechnicalError.openfaas_not_reachable_tuple()
  end

  defp response(
         {:ok, %Finch.Response{status: status_code, body: body}},
         _action
       )
       when status_code not in [200, 202] do
    Logger.error(body)

    case status_code do
      400 ->
        TechnicalError.bad_request_tuple(body)

      404 ->
        TechnicalError.error_404_tuple(body)

      500 ->
        TechnicalError.error_500_tuple(body)

      504 ->
        TechnicalError.timeout_tuple(body)

      _err ->
        TechnicalError.unknown_error_tuple(body)
    end
  end
end
