defmodule ApplicationRunner.ResourcesController do
  defmacro __using__(opts) do
    adapter_mod = Keyword.fetch!(opts, :adapter)

    quote do
      use ApplicationRunner, :controller

      alias ApplicationRunner.ApplicationServices
      alias ApplicationRunner.Environment
      alias ApplicationRunner.Guardian.AppGuardian

      @adapter_mod unquote(adapter_mod)

      def get_app_resource(conn, %{"app_name" => app_name, "resource" => resource_name}) do
        function_name = @adapter_mod.get_function_name(app_name)

        conn =
          conn
          |> put_resp_content_type("image/event-stream")
          |> put_resp_header("Content-Type", "application/octet-stream")
          |> send_chunked(200)

        with {:ok, stream} <-
               ApplicationServices.get_app_resource_stream(function_name, resource_name) do
          Enum.reduce(stream, conn, fn
            {:data, data}, conn ->
              IO.inspect(data)
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