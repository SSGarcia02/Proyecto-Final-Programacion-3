defmodule EmergenciaWeb.LoginLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Usuarios

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:error, nil)
     |> assign(:username, "")
     |> assign(:password, "")}
  end

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
    <div class="login-container">
      <h1>Emergencia</h1>

      <h2>Conectar</h2>

      <div :if={@error} class="error">
        {@error}
      </div>

      <form phx-submit="conectar">
        <div>
          <label for="username">Usuario</label>
          <input type="text" name="username" id="username" value={@username} />
        </div>

        <div>
          <label for="password">Contraseña</label>
          <input type="password" name="password" id="password" />
        </div>
        <button type="submit">Conectar</button>
      </form>

      <p class="hint">
        Si el usuario no existe, se registra automáticamente.
      </p>
    </div>
    """
  end
end
