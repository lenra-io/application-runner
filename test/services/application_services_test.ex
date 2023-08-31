defmodule ApplicationRunner.ApplicationServicesTest do
  use ApplicationRunner.ConnCase, async: false

  alias ApplicationRunner.ApplicationServices

  @function_name Ecto.UUID.generate()

  defp handle_resp(conn) do
    Plug.Conn.resp(conn, 200, "ok")
  end

  defp app_info_handler(app \\ %{name: @function_name}) do
    fn conn ->
      Plug.Conn.resp(conn, 200, Jason.encode!(app))
    end
  end

  test "start app" do
    bypass = Bypass.open(port: 1234)
    Bypass.stub(bypass, "GET", "/system/function/#{@function_name}", app_info_handler())
    Bypass.stub(bypass, "PUT", "/system/functions", &handle_resp/1)

    # Check scale up
    Bypass.expect_once(
      bypass,
      "PUT",
      "/system/functions",
      fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        app = Jason.decode!(body)

        assert "1" = app["labels"]["com.openfaas.scale.min"]

        conn
        |> send_resp(200, "ok")
      end
    )

    ApplicationServices.start_app(@function_name)
  end

  test "stop app" do
    bypass = Bypass.open(port: 1234)
    Bypass.stub(bypass, "GET", "/system/function/#{@function_name}", app_info_handler())
    Bypass.stub(bypass, "PUT", "/system/functions", &handle_resp/1)

    # Check scale up
    Bypass.expect_once(
      bypass,
      "PUT",
      "/system/functions",
      fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        app = Jason.decode!(body)

        assert "1" = app["labels"]["com.openfaas.scale.min"]

        conn
        |> send_resp(200, "ok")
      end
    )

    ApplicationServices.start_app(@function_name)
  end
end
