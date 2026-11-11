defmodule EmergenciaWeb.SesionController do
  use EmergenciaWeb, :controller

  alias Emergencia.Usuarios

  @doc """
  Recibe el username ya autenticado (desde la LiveView de login)
  y lo guarda en la sesión HTTP.
  """
  def crear(conn, %{"username" => username}) do
    case Usuarios.buscar(username) do
      {:ok, usuario} ->
        conn
        |> put_session(:username, usuario.username)
        |> put_session(:tipo, Atom.to_string(usuario.tipo))
        |> put_session(:zona, usuario.zona)
        |> redirect(to: "/dashboard")

      {:error, :no_encontrado} ->
        conn
        |> put_flash(:error, "Usuario no encontrado")
        |> redirect(to: "/login")
    end
  end

  @doc """
  Cierra la sesión: desconecta al usuario y limpia la sesión HTTP.
  """
  def eliminar(conn, _params) do
    case get_session(conn, :username) do
      nil ->
        :ok

      username ->
        # <-- NUEVO: REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(username, "Cerró sesión en el sistema")
        Usuarios.desconectar(username)
    end

    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
