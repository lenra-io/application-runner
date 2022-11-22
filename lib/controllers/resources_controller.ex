defmodule ApplicationRunner.ResourcesController do
  defmacro __using__(_opts) do
    quote do
      use ApplicationRunner, :controller

      alias ApplicationRunner.ApplicationServices

      @adapter Application.compile_env(:application_runner, :adapter)

      def get_app_resource(conn, %{"app_name" => app_name, "resource" => resource_name}) do
        function_name = @adapter.get_function_name(app_name)

        conn =
          conn
          |> put_resp_content_type("image/event-stream")
          |> put_resp_header("Content-Type", "application/octet-stream")
          |> send_chunked(200)

        with {:ok, stream} <-
               ApplicationServices.get_app_resource_stream(function_name, resource_name) do
          Enum.reduce(stream, conn, fn
            {:data, data}, conn ->
              {:ok, conn_res} = conn |> chunk(data)
              conn_res

            _, conn ->
              conn
          end)
        end
      end
    end
  end
end
