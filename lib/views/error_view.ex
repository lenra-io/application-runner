defmodule ApplicationRunner.ErrorView do
  use ApplicationRunner, :view
  require Logger

  def render("500.json", _assigns) do
    %{"errors" => [%{code: 500, message: "Internal Server Error"}], "success" => false}
  end

  def render("404.json", _assigns) do
    %{"errors" => [%{code: 404, message: "Page not found"}], "success" => false}
  end

  def render("401.json", %{message: message}) do
    %{"errors" => [%{code: 401, message: message}], "success" => false}
  end

  def render("401.json", _assigns) do
    %{"errors" => [%{code: 401, message: "Unauthorized"}], "success" => false}
  end

  def render("403.json", %{error: error}) do
    %{"errors" => [error], "success" => false}
  end

  def render("403.json", _assigns) do
    %{"errors" => [%{code: 403, message: "Forbidden"}], "success" => false}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(_template, assigns) do
    Logger.debug("ERROR VIEW NOT FOUND")
    render("500.json", assigns)
  end
end
