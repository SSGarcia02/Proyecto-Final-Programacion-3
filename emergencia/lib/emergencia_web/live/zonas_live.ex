defmodule EmergenciaWeb.ZonasLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Zonas
  alias Emergencia.Zonas.Zona

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:zonas, Zonas.listar())
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("registrar", params, socket) do
    # Por ahora crearemos una zona simple sin sectores anidados desde la UI
    # (para no complicar el formulario HTML)

    codigo = String.trim(params["codigo"])
    nombre = String.trim(params["nombre"])
    nivel_str = params["nivel"]

    with {:ok, nivel} <- Zona.parsear_nivel(nivel_str),
         %Zona{} = zona <- %Zona{codigo: codigo, nombre: nombre, nivel: nivel} do
      case Zonas.registrar(zona) do
        {:ok, _zona} ->
          {:noreply,
           socket
           |> assign(:zonas, Zonas.listar())
           |> assign(:error, nil)}

        {:error, :zona_ya_existe} ->
          {:noreply, assign(socket, :error, "Ya existe una zona con ese código.")}
      end
    else
      {:error, :nivel_invalido} ->
        {:noreply, assign(socket, :error, "El nivel seleccionado no es válido.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <header>
        <h1>Gestión de Zonas</h1>
        <a href="/dashboard">Volver al Dashboard</a>
      </header>

      <div :if={@error} class="error">
        {@error}
      </div>

      <div class="form-section">
        <h2>Registrar Nueva Zona</h2>

        <form phx-submit="registrar">
          <div>
            <label>Código (Ej. Z001):</label> <input type="text" name="codigo" required />
          </div>

          <div>
            <label>Nombre:</label> <input type="text" name="nombre" required />
          </div>

          <div>
            <label>Nivel de afectación:</label>
            <select name="nivel">
              <option value="critico">Crítico</option>

              <option value="alto">Alto</option>

              <option value="medio">Medio</option>

              <option value="bajo">Bajo</option>
            </select>
          </div>
          <button type="submit">Registrar Zona</button>
        </form>
      </div>

      <div class="list-section">
        <h2>Zonas Registradas</h2>

        <table>
          <thead>
            <tr>
              <th>Código</th>

              <th>Nombre</th>

              <th>Nivel</th>

              <th>Personas Afectadas (Recursivo)</th>
            </tr>
          </thead>

          <tbody>
            <tr :for={zona <- @zonas}>
              <td>{zona.codigo}</td>

              <td>{zona.nombre}</td>

              <td>{zona.nivel}</td>

              <td>{zona.personas_afectadas}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
