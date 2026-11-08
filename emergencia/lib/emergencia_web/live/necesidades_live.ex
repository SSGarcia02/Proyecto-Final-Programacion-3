defmodule EmergenciaWeb.NecesidadesLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Necesidades
  alias Emergencia.Necesidades.Necesidad
  alias Emergencia.Zonas
  alias Emergencia.Recursos

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:necesidades, Necesidades.listar_ordenadas())
     |> assign(:zonas, Zonas.listar())
     |> assign(:recursos, Recursos.listar())
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("registrar", params, socket) do
    # Generamos un ID único simple (puedes mejorarlo con un contador)
    id = "N" <> Integer.to_string(System.unique_integer([:positive]))
    tipo_str = params["tipo"]
    prioridad_str = params["prioridad"]

    with {:ok, tipo} <- Necesidad.parsear_tipo(tipo_str),
         {:ok, prioridad} <- Necesidad.parsear_prioridad(prioridad_str),
         {cantidad, ""} when cantidad > 0 <- Integer.parse(params["cantidad"]) do
      necesidad = %Necesidad{
        id: id,
        tipo: tipo,
        cantidad_requerida: cantidad,
        zona: params["zona"],
        prioridad: prioridad,
        descripcion: String.trim(params["descripcion"]),
        # En un caso real, sería el usuario en sesión
        responsable: "Coordinador"
      }

      case Necesidades.registrar(necesidad) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:necesidades, Necesidades.listar_ordenadas())
           |> assign(:error, nil)}

        {:error, motivo} ->
          {:noreply, assign(socket, :error, "Error: #{motivo}")}
      end
    else
      _ ->
        {:noreply, assign(socket, :error, "Verifica los datos. La cantidad debe ser mayor a 0.")}
    end
  end

  @impl true
  def handle_event(
        "asignar",
        %{"necesidad_id" => id, "recurso" => codigo, "cantidad" => cant_str},
        socket
      ) do
    case Integer.parse(cant_str) do
      {cantidad, ""} when cantidad > 0 ->
        case Necesidades.asignar_recurso(id, codigo, cantidad) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:necesidades, Necesidades.listar_ordenadas())
             |> assign(:recursos, Recursos.listar())
             |> assign(:error, nil)}

          {:error, :ya_atendida} ->
            {:noreply, assign(socket, :error, "Esta necesidad ya fue atendida.")}

          {:error, :sin_existencias} ->
            {:noreply, assign(socket, :error, "No hay suficientes recursos en el inventario.")}

          _ ->
            {:noreply, assign(socket, :error, "Error al asignar.")}
        end

      _ ->
        {:noreply, assign(socket, :error, "Cantidad inválida.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <h1>Gestión de Necesidades</h1>
        <a href="/dashboard" style="text-decoration: none; color: #007bff; font-weight: bold;">← Volver al Dashboard</a>
      </header>

      <div :if={@error} class="error">{@error}</div>

      <div class="form-section">
        <h2>Registrar Necesidad</h2>
        <form phx-submit="registrar" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
          <div>
            <label>Tipo:</label>
            <select name="tipo">
              <%= for t <- Necesidad.tipos() do %>
                <option value={t}>{t}</option>
              <% end %>
            </select>
          </div>
          <div>
            <label>Prioridad:</label>
            <select name="prioridad">
              <%= for p <- Necesidad.prioridades() do %>
                <option value={p}>{p}</option>
              <% end %>
            </select>
          </div>
          <div>
            <label>Cantidad Requerida:</label>
            <input type="number" name="cantidad" min="1" value="1" required />
          </div>
          <div>
            <label>Zona Afectada:</label>
            <select name="zona">
              <%= for z <- @zonas do %>
                <option value={z.codigo}>{z.codigo} - {z.nombre}</option>
              <% end %>
            </select>
          </div>
          <div style="grid-column: span 2;">
            <label>Descripción:</label>
            <input type="text" name="descripcion" placeholder="Ej. Agua para 30 personas" required />
          </div>
          <div style="grid-column: span 2; margin-top: 1rem;">
            <button type="submit">Registrar Necesidad</button>
          </div>
        </form>
      </div>

      <div class="list-section">
        <h2>Listado de Necesidades (Ordenadas por Prioridad)</h2>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Prioridad</th>
              <th>Tipo</th>
              <th>Cantidad</th>
              <th>Zona</th>
              <th>Estado</th>
              <th>Acción</th>
            </tr>
          </thead>
          <tbody>
            <%= for n <- @necesidades do %>
              <tr>
                <td>{n.id}</td>
                <td style={"font-weight: bold; color: " <> if n.prioridad == :critica, do: "red", else: "#333"}>
                  {n.prioridad}
                </td>
                <td>{n.tipo}</td>
                <td>{n.cantidad_requerida}</td>
                <td>{n.zona}</td>
                <td>{n.estado}</td>
                <td>
                  <%= if n.estado == "pendiente" do %>
                    <form
                      phx-submit="asignar"
                      style="display: flex; gap: 0.5rem; align-items: center;"
                    >
                      <!-- Usamos necesidad_id para evitar el warning de LiveView -->
                      <input type="hidden" name="necesidad_id" value={n.id} />

                      <select name="recurso" style="width: auto; padding: 0.2rem;">
                        <!-- Filtramos los recursos para que coincidan con el tipo de necesidad -->
                        <%= for r <- Enum.filter(@recursos, fn r -> r.categoria == Atom.to_string(n.tipo) end) do %>
                          <option value={r.codigo}>{r.nombre}</option>
                        <% end %>
                      </select>

                      <input
                        type="number"
                        name="cantidad"
                        value={n.cantidad_requerida}
                        min="1"
                        style="width: 60px; padding: 0.2rem;"
                        required
                      />

                      <button type="submit" style="padding: 0.2rem 0.5rem; font-size: 0.8rem;">Asignar</button>
                    </form>
                  <% else %>
                    <span style="color: green; font-weight: bold;">✓ {n.recurso_asignado}</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
