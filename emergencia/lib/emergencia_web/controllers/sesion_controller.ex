defmodule EmergenciaWeb.SesionController do
  @moduledoc """
  Controlador encargado de gestionar la sesión HTTP del usuario.

  Este controlador actúa como puente entre la LiveView de Login y la sesión
  HTTP de Phoenix. Como las LiveViews no pueden escribir en la cookie de sesión
  directamente, la LiveView redirige a este controlador con el username ya
  autenticado para que guarde los datos en la sesión.

  También maneja el cierre de sesión (`/logout`), que desconecta al usuario
  en el GenServer y limpia la cookie.
  """

  use EmergenciaWeb, :controller

  alias Emergencia.Usuarios

  @doc """
  Recibe el username ya autenticado desde la LiveView de Login y lo guarda en
  la sesión HTTP (cookie).

  Guarda tres datos en la sesión: `username`, `tipo` (como string) y `zona`.
  Luego redirige al Dashboard.

  Si el usuario no existe en el sistema, redirige al login con un mensaje de error.

  ## Parámetros
  - `conn`: La conexión HTTP actual.
  - `params`: Un mapa con la clave `"username"`.

  ## Retorna
  - `Plug.Conn` con redirección a `/dashboard` si el usuario existe.
  - `Plug.Conn` con redirección a `/login` si no existe.
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
  Cierra la sesión del usuario actual.

  Si hay un username en la sesión, registra la actividad de "Cerró sesión" y
  llama a `Usuarios.desconectar/1` para actualizar el estado del GenServer.
  Luego limpia la cookie de sesión y redirige al login.

  ## Parámetros
  - `conn`: La conexión HTTP actual.

  ## Retorna
  - `Plug.Conn` con redirección a `/login`.
  """
  def eliminar(conn, _params) do
    case get_session(conn, :username) do
      nil ->
        :ok

      username ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(username, "Cerró sesión en el sistema")
        Usuarios.desconectar(username)
    end

    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
