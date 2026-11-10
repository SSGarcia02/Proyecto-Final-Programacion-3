defmodule EmergenciaWeb.MascotasLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Mascotas
  alias Emergencia.Mascotas.Mascota
  alias Emergencia.Zonas

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:mascotas, Mascotas.listar())
     |> assign(:zonas, Zonas.listar())
     |> assign(:mascota_expandida, nil)
     |> assign(:coincidencias, [])
     |> assign(:filtros, %{"especie" => "", "zona" => "", "estado" => ""})
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("registrar", params, socket) do
    id = "M" <> Integer.to_string(System.unique_integer([:positive]))

    mascota = %Mascota{
      id: id,
      tipo_reporte: params["tipo_reporte"],
      especie: params["especie"],
      nombre: String.trim(params["nombre"] || ""),
      caracteristicas: String.trim(params["caracteristicas"] || ""),
      color: String.trim(params["color"] || ""),
      tamano: params["tamano"],
      zona: params["zona"],
      contacto: String.trim(params["contacto"])
    }

    case Mascotas.registrar(mascota) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:mascotas, Mascotas.listar())
         |> assign(:error, nil)}

      {:error, motivo} ->
        {:noreply, assign(socket, :error, "Error: #{motivo}")}
    end
  end

  def handle_event("toggle_mascota", %{"id" => id}, socket) do
    if socket.assigns.mascota_expandida == id do
      {:noreply, assign(socket, :mascota_expandida, nil)}
    else
      # Al abrir, buscamos coincidencias automáticamente
      coincidencias =
        case Mascotas.buscar_coincidencias(id) do
          {:ok, lista} -> lista
          _ -> []
        end

      {:noreply,
       socket
       |> assign(:mascota_expandida, id)
       |> assign(:coincidencias, coincidencias)}
    end
  end

  def handle_event("resolver", %{"id1" => id1, "id2" => id2}, socket) do
    case Mascotas.resolver_coincidencia(id1, id2) do
      {:ok, _, _} ->
        {:noreply,
         socket
         |> assign(:mascotas, Mascotas.listar())
         |> assign(:mascota_expandida, nil)
         |> assign(:coincidencias, [])
         |> assign(:error, nil)}

      _ ->
        {:noreply, assign(socket, :error, "Error al resolver la coincidencia.")}
    end
  end

  @impl true
  def handle_event("filtrar", params, socket) do
    filtros = %{
      "especie" => params["especie"],
      "zona" => params["zona"],
      "estado" => params["estado"]
    }

    {:noreply, assign(socket, filtros: filtros)}
  end

  def handle_event("nada", _, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <h1>Mascotas Perdidas y Encontradas</h1>
        <a href="/dashboard" style="text-decoration: none; color: #007bff; font-weight: bold;">← Volver al Dashboard</a>
      </header>

      <div :if={@error} class="error">{@error}</div>

      <div class="form-section">
        <h2>Registrar Reporte de Mascota</h2>
        <form
          phx-submit="registrar"
          style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem;"
        >
          <div>
            <label>Tipo de Reporte:</label>
            <select name="tipo_reporte">
              <option value="perdida">Perdida</option>
              <option value="encontrada">Encontrada</option>
            </select>
          </div>
          <div>
            <label>Especie:</label>
            <select name="especie">
              <%= for e <- Mascota.especies() do %>
                <option value={e}>{e}</option>
              <% end %>
            </select>
          </div>
          <div>
            <label>Nombre (Opcional):</label>
            <input type="text" name="nombre" placeholder="Ej. Luna" />
          </div>
          <div>
            <label>Color:</label>
            <input type="text" name="color" placeholder="Ej. Negra" />
          </div>
          <div>
            <label>Tamaño:</label>
            <select name="tamano">
              <%= for t <- Mascota.tamanos() do %>
                <option value={t}>{t}</option>
              <% end %>
            </select>
          </div>
          <div>
            <label>Zona:</label>
            <select name="zona">
              <%= for z <- @zonas do %>
                <option value={z.codigo}>{z.codigo} - {z.nombre}</option>
              <% end %>
            </select>
          </div>
          <div style="grid-column: span 2;">
            <label>Características (Opcional):</label>
            <input type="text" name="caracteristicas" placeholder="Ej. Tiene collar rojo" />
          </div>
          <div>
            <label>Contacto:</label>
            <input type="text" name="contacto" placeholder="Ej. 3001234567" required />
          </div>
          <div style="grid-column: span 3; margin-top: 1rem;">
            <button type="submit">Registrar Mascota</button>
          </div>
        </form>
      </div>

      <!-- BARRA DE FILTROS -->
      <div class="form-section">
        <form phx-change="filtrar" style="display: flex; gap: 1rem; align-items: center;">
          <span style="font-weight: bold;">Filtrar por:</span>

          <select name="especie" style="width: auto;">
            <option value="">Todas las especies</option>
            <%= for e <- Mascota.especies() do %>
              <option value={e} selected={@filtros["especie"] == e}>{e}</option>
            <% end %>
          </select>

          <select name="zona" style="width: auto;">
            <option value="">Todas las zonas</option>
            <%= for z <- @zonas do %>
              <option value={z.codigo} selected={@filtros["zona"] == z.codigo}>{z.nombre}</option>
            <% end %>
          </select>

          <select name="estado" style="width: auto;">
            <option value="">Todos los estados</option>
            <%= for e <- Mascota.estados() do %>
              <option value={e} selected={@filtros["estado"] == e}>
                {String.capitalize(String.replace(e, "_", " "))}
              </option>
            <% end %>
          </select>
        </form>
      </div>

      <div class="list-section">
        <h2>Reportes Registrados</h2>

        <div style="overflow-x: auto; width: 100%;">
          <table style="white-space: nowrap;">
            <thead>
              <tr>
                <th>ID</th>
                <th>Tipo</th>
                <th>Especie</th>
                <th>Nombre</th>
                <th>Zona</th>
                <th>Estado</th>
              </tr>
            </thead>
            <tbody>
              <!-- FILTRADO EN EL RENDER -->
              <%= for m <- @mascotas,
                    (@filtros["especie"] == "" or m.especie == @filtros["especie"]),
                    (@filtros["zona"] == "" or m.zona == @filtros["zona"]),
                    (@filtros["estado"] == "" or m.estado == @filtros["estado"]) do %>
                <tr
                  phx-click="toggle_mascota"
                  phx-value-id={m.id}
                  style="cursor: pointer; background-color: #f8f9fa;"
                >
                  <td style="font-weight: bold; color: #007bff;">
                    {if @mascota_expandida == m.id, do: "▼", else: "▶"} {m.id}
                  </td>
                  <td>
                    <span style={"padding: 0.2rem 0.5rem; border-radius: 4px; color: white; font-size: 0.8rem; background-color: " <> if m.tipo_reporte == "perdida", do: "#dc3545", else: "#28a745"}>
                      {String.capitalize(m.tipo_reporte)}
                    </span>
                  </td>
                  <td>{String.capitalize(m.especie)}</td>
                  <td>{m.nombre || "Desconocido"}</td>
                  <td>{m.zona}</td>
                  <td>
                    <span style={"font-weight: bold; " <>
                      case m.estado do
                        "resuelta" -> "color: green;"
                        "posible_coincidencia" -> "color: #ffc107;"
                        _ -> "color: #007bff;"
                      end
                    }>
                      {String.capitalize(String.replace(m.estado, "_", " "))}
                    </span>
                  </td>
                </tr>

                <!-- FILA EXPANDIDA (Coincidencias) -->
                <tr :if={@mascota_expandida == m.id}>
                  <td colspan="6" style="padding: 0; background-color: #ffffff;">
                    <div style="padding: 1rem; border-left: 4px solid #007bff; margin: 1rem; white-space: normal;">
                      <div style="margin-bottom: 1rem;">
                        <p><strong>Características:</strong> {m.caracteristicas || "N/A"}</p>
                        <p><strong>Color / Tamaño:</strong> {m.color} / {m.tamano}</p>
                        <p><strong>Contacto:</strong> {m.contacto}</p>
                        <%= if m.reporte_vinculado do %>
                          <p style="color: green; font-weight: bold;">
                            ✓ Resuelta y vinculada con el reporte: {m.reporte_vinculado}
                          </p>
                        <% end %>
                      </div>

                      <!-- SECCIÓN DE COINCIDENCIAS -->
                      <%= if m.estado != "resuelta" do %>
                        <hr style="margin: 1rem 0;" />
                        <h4 style="margin-top: 0; color: #555;">Posibles Coincidencias</h4>

                        <%= if Enum.empty?(@coincidencias) do %>
                          <p style="color: #888; font-style: italic;">
                            No se encontraron coincidencias con otros reportes aún.
                          </p>
                        <% else %>
                          <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                            <%= for {c, puntaje} <- @coincidencias do %>
                              <div style="display: flex; justify-content: space-between; align-items: center; background: #e9ecef; padding: 0.5rem; border-radius: 4px;">
                                <div>
                                  <strong>{c.nombre || "Desconocido"}</strong>
                                  ({c.tipo_reporte})
                                  - Puntaje de similitud:
                                  <strong style="color: #007bff;">{puntaje}%</strong>
                                </div>
                                <button
                                  phx-click="resolver"
                                  phx-value-id1={m.id}
                                  phx-value-id2={c.id}
                                  data-confirm="¿Confirmar que son la misma mascota y cerrar ambos reportes?"
                                  style="padding: 0.2rem 0.5rem; font-size: 0.8rem; background-color: #28a745; margin: 0;"
                                >
                                  Confirmar Coincidencia
                                </button>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
