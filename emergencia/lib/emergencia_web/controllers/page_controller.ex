defmodule EmergenciaWeb.PageController do
  use EmergenciaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
