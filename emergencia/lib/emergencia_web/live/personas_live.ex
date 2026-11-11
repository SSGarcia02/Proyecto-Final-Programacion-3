defmodule EmergenciaWeb.PersonasLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Personas
  alias Emergencia.Personas.{Persona, Mensaje}
  alias Emergencia.Zonas

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:personas, Personas.listar_personas())
     |> assign(:zonas, Zonas.listar())
     |> assign(:persona_expandida, nil)
     |> assign(:mensajes_actuales, [])
     |> assign(:busqueda, "")
     |> assign(:filtro_zona, "")
     |> assign(:filtro_estado, "")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("filtrar", params, socket) do
    busqueda = params["busqueda"] || ""
    zona = params["zona"] || ""
    estado = params["estado"] || ""

    filtradas =
      Personas.listar_personas()
      |> Enum.filter(fn p ->
        match_texto =
          busqueda == "" or
            String.contains?(String.downcase(p.documento), String.downcase(busqueda)) or
            String.contains?(String.downcase(p.nombre), String.downcase(busqueda))

        match_zona = zona == "" or p.zona == zona
        match_estado = estado == "" or p.estado == estado

        match_texto and match_zona and match_estado
      end)

    {:noreply,
     socket
     |> assign(:personas, filtradas)
     |> assign(:busqueda, busqueda)
     |> assign(:filtro_zona, zona)
     |> assign(:filtro_estado, estado)}
  end

  def handle_event("marcar_leido", %{"id" => id, "documento" => doc}, socket) do
    Personas.marcar_mensaje_leido(id)
    mensajes = Personas.listar_mensajes(doc)
    {:noreply, assign(socket, mensajes_actuales: mensajes)}
  end

  @impl true
  def handle_event("registrar", params, socket) do
    documento = String.trim(params["documento"])
    nombre = String.trim(params["nombre"])

    edad =
      case Integer.parse(params["edad"] || "") do
        {num, ""} -> num
        _ -> nil
      end

    persona = %Persona{
      documento: documento,
      nombre: nombre,
      zona: params["zona"],
      edad: edad
    }

    case Personas.registrar_persona(persona) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:personas, Personas.listar_personas())
         |> assign(:error, nil)}

      {:error, :persona_ya_existe} ->
        {:noreply, assign(socket, :error, "Ya existe una persona con ese documento.")}
    end
  end

  def handle_event("cambiar_estado", %{"documento" => doc, "estado" => nuevo_estado}, socket) do
    case Personas.cambiar_estado(doc, nuevo_estado) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:personas, Personas.listar_personas())
         |> assign(:error, nil)}

      _ ->
        {:noreply, assign(socket, :error, "Error al cambiar estado.")}
    end
  end

  def handle_event("toggle_persona", %{"documento" => documento}, socket) do
    if socket.assigns.persona_expandida == documento do
      {:noreply, assign(socket, :persona_expandida, nil)}
    else
      mensajes = Personas.listar_mensajes(documento)

      {:noreply,
       socket
       |> assign(:persona_expandida, documento)
       |> assign(:mensajes_actuales, mensajes)}
    end
  end

  def handle_event("nada", _, socket), do: {:noreply, socket}

  def handle_event(
        "enviar_mensaje",
        %{"documento" => doc, "remitente" => remitente, "contenido" => contenido},
        socket
      ) do
    id = "M" <> Integer.to_string(System.unique_integer([:positive]))

    mensaje = %Mensaje{
      id: id,
      documento_destino: doc,
      remitente: String.trim(remitente),
      contenido: String.trim(contenido)
    }

    case Personas.enviar_mensaje(mensaje) do
      {:ok, _} ->
        mensajes = Personas.listar_mensajes(doc)

        {:noreply,
         socket
         |> assign(:mensajes_actuales, mensajes)
         |> assign(:error, nil)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <h1>Personas y Mensajes</h1>
        <a href="/dashboard" style="text-decoration: none; color: #007bff; font-weight: bold;">← Volver al Dashboard</a>
      </header>

      <div :if={@error} class="error">{@error}</div>

      <!-- FORMULARIO DE REGISTRO -->
      <div class="form-section">
        <h2>Registrar Persona Afectada</h2>
        <form
          phx-submit="registrar"
          style="display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 1rem;"
        >
          <div>
            <label>Documento:</label>
            <input type="text" name="documento" required />
          </div>
          <div>
            <label>Nombre Completo:</label>
            <input type="text" name="nombre" required />
          </div>
          <div>
            <label>Edad:</label>
            <input type="number" name="edad" min="0" />
          </div>
          <div>
            <label>Zona:</label>
            <select name="zona">
              <%= for z <- @zonas do %>
                <option value={z.codigo}>{z.codigo} - {z.nombre}</option>
              <% end %>
            </select>
          </div>
          <div style="grid-column: span 4; margin-top: 1rem;">
            <button type="submit">Registrar Persona</button>
          </div>
        </form>
      </div>

      <!-- FILTROS DE BÚSQUEDA -->
      <div class="form-section">
        <form phx-change="filtrar" style="display: flex; gap: 1rem; align-items: center; flex-wrap: wrap;">
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <label style="margin: 0; white-space: nowrap; font-weight: bold;">Buscar:</label>
            <input
              type="text"
              name="busqueda"
              value={@busqueda}
              placeholder="Nombre o documento..."
              phx-debounce="300"
            />
          </div>

          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <label style="margin: 0; white-space: nowrap; font-weight: bold;">Zona:</label>
            <select name="zona" style="width: auto; margin: 0;">
              <option value="">Todas</option>
              <%= for z <- @zonas do %>
                <option value={z.codigo} selected={@filtro_zona == z.codigo}>{z.nombre}</option>
              <% end %>
            </select>
          </div>

          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <label style="margin: 0; white-space: nowrap; font-weight: bold;">Estado:</label>
            <select name="estado" style="width: auto; margin: 0;">
              <option value="">Todos</option>
              <%= for est <- Persona.estados() do %>
                <option value={est} selected={@filtro_estado == est}>{String.capitalize(String.replace(est, "_", " "))}</option>
              <% end %>
            </select>
          </div>
        </form>
      </div>

      <div class="list-section">
        <h2>Personas Registradas (Click para ver mensajes e historial)</h2>

        <div style="overflow-x: auto; width: 100%;">
          <table style="white-space: nowrap;">
            <thead>
              <tr>
                <th>Documento</th>
                <th>Nombre</th>
                <th>Edad</th>
                <th>Zona</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @personas do %>
                <tr
                  phx-click="toggle_persona"
                  phx-value-documento={p.documento}
                  style="cursor: pointer; background-color: #f8f9fa;"
                >
                  <td style="font-weight: bold; color: #007bff;">
                    {if @persona_expandida == p.documento, do: "▼", else: "▶"} {p.documento}
                  </td>
                  <td>{p.nombre}</td>
                  <td>{p.edad || "N/A"}</td>
                  <td>
                    {case Enum.find(@zonas, &(&1.codigo == p.zona)) do
                      nil -> p.zona
                      z -> z.nombre
                    end}
                  </td>
                  <td>
                    <span style={"padding: 0.2rem 0.5rem; border-radius: 4px; color: white; font-size: 0.8rem; background-color: " <>
                      case p.estado do
                        "reunificada" -> "#28a745"
                        "localizada" -> "#17a2b8"
                        "sin_informacion" -> "#6c757d"
                        _ -> "#ffc107"
                      end
                    }>
                      {String.capitalize(String.replace(p.estado, "_", " "))}
                    </span>
                  </td>
                  <td>
                    <div phx-click="nada">
                      <form
                        phx-submit="cambiar_estado"
                        style="display: flex; gap: 0.5rem; align-items: center; margin: 0;"
                      >
                        <input type="hidden" name="documento" value={p.documento} />
                        <select name="estado" style="width: auto; padding: 0.2rem; margin: 0;">
                          <%= for est <- Persona.estados() do %>
                            <option value={est}>
                              {String.capitalize(String.replace(est, "_", " "))}
                            </option>
                          <% end %>
                        </select>
                        <button
                          type="submit"
                          style="padding: 0.2rem 0.5rem; font-size: 0.8rem; margin: 0;"
                        >Actualizar</button>
                      </form>
                    </div>
                  </td>
                </tr>

                <!-- FILA EXPANDIDA: Mensajes e Historial -->
                <tr :if={@persona_expandida == p.documento}>
                  <td colspan="6" style="padding: 0; background-color: #ffffff;">
                    <div style="padding: 1rem; border-left: 4px solid #007bff; margin: 1rem; white-space: normal; display: grid; grid-template-columns: 1fr 1fr; gap: 2rem;">
                      <!-- HISTORIAL -->
                      <div>
                        <h4 style="margin-top: 0; color: #555;">Historial de Estados</h4>
                        <ul style="padding-left: 1.5rem; font-size: 0.9rem;">
                          <%= for h <- p.historial_estados do %>
                            <li>
                              <strong>{String.capitalize(String.replace(h["estado"], "_", " "))}</strong>
                              - {h["fecha"]}
                            </li>
                          <% end %>
                        </ul>
                      </div>

                      <!-- MENSAJES -->
                      <div>
                        <h4 style="margin-top: 0; color: #555;">Mensajes para {p.nombre}</h4>

                        <%= if Enum.empty?(@mensajes_actuales) do %>
                          <p style="color: #888; font-style: italic; font-size: 0.9rem;">
                            No hay mensajes aún.
                          </p>
                        <% else %>
                          <div style="max-height: 200px; overflow-y: auto; margin-bottom: 1rem;">
                            <%= for m <- @mensajes_actuales do %>
                              <div style={"margin-bottom: 0.5rem; padding: 0.5rem; border-radius: 4px; border: 1px solid " <> if m.leido, do: "#c3e6cb", else: "#f5c6cb"}>
                                <p style="margin: 0;">
                                  <strong>{m.remitente}:</strong> {m.contenido}
                                </p>
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 0.2rem;">
                                  <small style="color: #888;">{m.fecha}</small>
                                  <%= if m.leido do %>
                                    <span style="color: green; font-size: 0.8rem; font-weight: bold;">✓ Leído</span>
                                  <% else %>
                                    <button
                                      phx-click="marcar_leido"
                                      phx-value-id={m.id}
                                      phx-value-documento={p.documento}
                                      style="padding: 0.1rem 0.3rem; font-size: 0.7rem; background-color: #007bff;"
                                    >Marcar Leído</button>
                                  <% end %>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        <% end %>

                        <form
                          phx-submit="enviar_mensaje"
                          style="display: flex; flex-direction: column; gap: 0.5rem; background: #f8f9fa; padding: 0.5rem; border-radius: 4px;"
                        >
                          <input type="hidden" name="documento" value={p.documento} />
                          <input
                            type="text"
                            name="remitente"
                            placeholder="Tu nombre (familiar)"
                            required
                            style="padding: 0.2rem;"
                          />
                          <textarea
                            name="contenido"
                            placeholder="Escribe un mensaje..."
                            required
                            style="padding: 0.2rem; resize: vertical;"
                            rows="2"
                          ></textarea>
                          <button type="submit" style="padding: 0.2rem 0.5rem; font-size: 0.8rem;">Enviar Mensaje</button>
                        </form>
                      </div>
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
