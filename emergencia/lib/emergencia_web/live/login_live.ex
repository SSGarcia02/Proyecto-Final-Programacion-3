defmodule EmergenciaWeb.LoginLive do
  @moduledoc """
  LiveView para el inicio de sesión y registro automático de usuarios.

  Esta vista muestra el formulario de conexión y se comunica con el GenServer
  de Usuarios para validar las credenciales. Cumple con la regla del enunciado:
  si el usuario no existe, se registra automáticamente con los datos
  proporcionados.
  """

  use EmergenciaWeb, :live_view

  alias Emergencia.Usuarios

  @doc """
  Inicializa la vista con los campos vacíos y sin errores.
  """
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:error, nil)
     |> assign(:username, "")
     |> assign(:password, "")}
  end

  @doc """
  Maneja el evento de conexión cuando el usuario envía el formulario.

  Valida que los campos no estén vacíos, llama a `Usuarios.conectar/2` y, si la
  autenticación es exitosa, registra la actividad y redirige al controlador de
  sesión para guardar el usuario en la cookie HTTP.

  ## Retorna
  - Redirección a `/sesion/crear` si el login es exitoso.
  - Mensaje de error si las credenciales son incorrectas o los campos están vacíos.
  """
  @impl true
  def handle_event("conectar", %{"username" => username, "password" => password}, socket) do
    username = String.trim(username)
    password = String.trim(password)

    cond do
      username == "" ->
        {:noreply, assign(socket, :error, "El usuario no puede estar vacío")}

      password == "" ->
        {:noreply, assign(socket, :error, "La contraseña no puede estar vacía")}

      true ->
        case Usuarios.conectar(username, password) do
          {:ok, usuario} ->
            Usuarios.registrar_actividad(usuario.username, "Inició sesión en el sistema")
            {:noreply, redirect(socket, to: "/sesion/crear?username=#{usuario.username}")}

          {:error, :password_incorrecta} ->
            {:noreply, assign(socket, :error, "Contraseña incorrecta")}

          {:error, motivo} ->
            {:noreply, assign(socket, :error, "Error: #{motivo}")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="login-page">
      <div class="login-card">
        <h1>Emergencia</h1>
        <h2>Iniciar Sesión</h2>

        <div :if={@error} class="error">
          {@error}
        </div>

        <form phx-submit="conectar">
          <div class="form-group">
            <label for="username">Usuario</label>
            <input
              type="text"
              name="username"
              id="username"
              value={@username}
              placeholder="Ingresa tu usuario"
            />
          </div>

          <div class="form-group">
            <label for="password">Contraseña</label>
            <input
              type="password"
              name="password"
              id="password"
              placeholder="••••••••"
            />
          </div>

          <button type="submit">Conectar</button>
        </form>

        <p class="hint">
          Si el usuario no existe, se registra automáticamente.
        </p>
      </div>
    </div>
    """
  end
end
