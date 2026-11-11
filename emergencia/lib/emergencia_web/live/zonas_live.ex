defmodule EmergenciaWeb.ZonasLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Zonas
  alias Emergencia.Zonas.{Zona, Sector, Punto}
  alias Emergencia.Usuarios
  alias Emergencia.Albergues
  alias Emergencia.Necesidades
  alias Emergencia.Recursos
  alias Emergencia.Personas
  alias Emergencia.Mascotas

  @impl true
  def mount(_params, session, socket) do
    tipo = session["tipo"] || "ciudadano"
    username = session["username"] || "desconocido"

    if tipo in ["coordinador", "administrador"] do
      {:ok,
       socket
       |> assign(:zonas, Zonas.listar())
       |> assign(:username, username)
       |> assign(:albergues, Albergues.listar())
       |> assign(:necesidades, Necesidades.listar_ordenadas())
       |> assign(:recursos, Recursos.listar())
       |> assign(:personas, Personas.listar_personas())
       |> assign(:mascotas, Mascotas.listar())
       |> assign(:error, nil)
       |> assign(:zona_editando, nil)
       |> assign(:zona_expandida, nil)}
    else
      {:ok, push_navigate(socket, to: "/dashboard")}
    end
  end

  # ---------- EVENTOS DE EXPANDIR / COLAPSAR ----------
  @impl true
  def handle_event("toggle_zona", %{"codigo" => codigo}, socket) do
    if socket.assigns.zona_expandida == codigo do
      {:noreply, assign(socket, :zona_expandida, nil)}
    else
      {:noreply, assign(socket, :zona_expandida, codigo)}
    end
  end

  # ---------- EVENTOS DE EDITAR ----------
  @impl true
  def handle_event("editar", %{"codigo" => codigo}, socket) do
    {:noreply, assign(socket, :zona_editando, codigo)}
  end

  def handle_event("cancelar_edicion", _, socket) do
    {:noreply, assign(socket, :zona_editando, nil)}
  end

  # ---------- EVENTOS DE ELIMINAR ----------
  def handle_event("eliminar", %{"codigo" => codigo}, socket) do
    Zonas.eliminar(codigo)
    Usuarios.registrar_actividad(socket.assigns.username, "Eliminó la zona #{codigo}")

    {:noreply,
     socket
     |> assign(:zonas, Zonas.listar())
     |> assign(:error, nil)
     |> assign(:zona_editando, nil)
     |> assign(:zona_expandida, nil)}
  end

  # ---------- EVENTO DE REGISTRAR / ACTUALIZAR ----------
  @impl true
  def handle_event("registrar", params, socket) do
    codigo = String.trim(params["codigo"])
    nombre = String.trim(params["nombre"])
    nivel_str = params["nivel"]

    sector_nombre = String.trim(params["sector_nombre"] || "")
    punto_nombre = String.trim(params["punto_nombre"] || "")

    personas =
      case Integer.parse(params["punto_personas"] || "0") do
        {num, ""} -> num
        _ -> 0
      end

    sectores_iniciales =
      if sector_nombre != "" and punto_nombre != "" do
        punto = %Punto{nombre: punto_nombre, personas_afectadas: personas}
        sector = %Sector{nombre: sector_nombre, puntos: [punto]}
        [sector]
      else
        []
      end

    with {:ok, nivel} <- Zona.parsear_nivel(nivel_str) do
      resultado =
        if socket.assigns.zona_editando do
          # EDICIÓN
          case Enum.find(socket.assigns.zonas, &(&1.codigo == socket.assigns.zona_editando)) do
            nil ->
              zona_nueva = %Zona{
                codigo: codigo,
                nombre: nombre,
                nivel: nivel,
                sectores: sectores_iniciales
              }

              Zonas.registrar(zona_nueva)

            zona_vieja ->
              sectores_actualizados =
                if sector_nombre != "" and punto_nombre != "" do
                  sectores_iniciales
                else
                  zona_vieja.sectores
                end

              zona_actualizada = %{
                zona_vieja
                | codigo: codigo,
                  nombre: nombre,
                  nivel: nivel,
                  sectores: sectores_actualizados
              }

              Zonas.eliminar(socket.assigns.zona_editando)
              Zonas.registrar(zona_actualizada)
          end
        else
          # CREACIÓN
          zona_nueva = %Zona{
            codigo: codigo,
            nombre: nombre,
            nivel: nivel,
            sectores: sectores_iniciales
          }

          Zonas.registrar(zona_nueva)
        end

      case resultado do
        {:ok, _} ->
          # CORREGIDO: usamos la variable `codigo` que sí existe en este scope
          Usuarios.registrar_actividad(
            socket.assigns.username,
            "Registró/Actualizó la zona #{codigo}"
          )

          {:noreply,
           socket
           |> assign(:zonas, Zonas.listar())
           |> assign(:error, nil)
           |> assign(:zona_editando, nil)
           |> assign(:zona_expandida, nil)}

        {:error, :zona_ya_existe} ->
          {:noreply, assign(socket, :error, "Ya existe una zona con ese código.")}
      end
    else
      {:error, :nivel_invalido} ->
        {:noreply, assign(socket, :error, "El nivel seleccionado no es válido.")}
    end
  end

  # ---------- RENDERIZADO ----------
  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <h1>Gestión de Zonas</h1>
        <a href="/dashboard" style="text-decoration: none; color: #007bff; font-weight: bold;">← Volver al Dashboard</a>
      </header>

      <div :if={@error} class="error">{@error}</div>

      <div class="form-section">
        <h2>{if @zona_editando, do: "Editar Zona", else: "Registrar Nueva Zona"}</h2>

        <form phx-submit="registrar">
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
            <div>
              <label>Código:</label>
              <input type="text" name="codigo" value={@zona_editando} required />
            </div>
            <div>
              <label>Nombre de la Zona:</label>
              <input
                type="text"
                name="nombre"
                value={
                  if @zona_editando,
                    do: Enum.find(@zonas, &(&1.codigo == @zona_editando)).nombre,
                    else: ""
                }
                required
              />
            </div>
          </div>

          <div style="margin-top: 1rem;">
            <label>Nivel de afectación:</label>
            <div style="display: flex; gap: 1rem; margin-top: 0.5rem;">
              <%= for nivel <- [:critico, :alto, :medio, :bajo] do %>
                <label style="display: flex; align-items: center; gap: 0.25rem; font-weight: normal; cursor: pointer;">
                  <input type="radio" name="nivel" value={nivel} checked={nivel == :critico} />
                  <span style="text-transform: capitalize;">{nivel}</span>
                </label>
              <% end %>
            </div>
          </div>

          <div style="border-top: 1px solid #ccc; margin-top: 1rem; padding-top: 1rem;">
            <h3 style="margin-bottom: 1rem; color: #333;">
              {if @zona_editando,
                do: "Actualizar Sector y Punto (Opcional)",
                else: "Agregar Sector y Punto (Opcional)"}
            </h3>

            <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem;">
              <div>
                <label>Nombre del Sector:</label>
                <input
                  type="text"
                  name="sector_nombre"
                  value={
                    if @zona_editando do
                      zona = Enum.find(@zonas, &(&1.codigo == @zona_editando))

                      case zona.sectores do
                        [s | _] -> s.nombre
                        _ -> ""
                      end
                    end
                  }
                  placeholder="Ej. Centro"
                />
              </div>

              <div>
                <label>Nombre del Punto:</label>
                <input
                  type="text"
                  name="punto_nombre"
                  value={
                    if @zona_editando do
                      zona = Enum.find(@zonas, &(&1.codigo == @zona_editando))

                      case zona.sectores do
                        [s | _] ->
                          case s.puntos do
                            [p | _] -> p.nombre
                            _ -> ""
                          end

                        _ ->
                          ""
                      end
                    end
                  }
                  placeholder="Ej. Escuela"
                />
              </div>

              <div>
                <label>Personas Afectadas:</label>
                <input
                  type="number"
                  name="punto_personas"
                  value={
                    if @zona_editando do
                      zona = Enum.find(@zonas, &(&1.codigo == @zona_editando))

                      case zona.sectores do
                        [s | _] ->
                          case s.puntos do
                            [p | _] -> p.personas_afectadas
                            _ -> 0
                          end

                        _ ->
                          0
                      end
                    else
                      0
                    end
                  }
                  min="0"
                />
              </div>
            </div>
          </div>

          <div style="display: flex; gap: 1rem; margin-top: 1.5rem;">
            <button type="submit">{if @zona_editando, do: "Guardar Cambios", else: "Registrar Zona"}</button>
            <button
              :if={@zona_editando}
              type="button"
              phx-click="cancelar_edicion"
              style="background-color: #6c757d;"
            >Cancelar</button>
          </div>
        </form>
      </div>

      <div class="list-section">
        <h2>Zonas Registradas (Click para expandir)</h2>
        <table>
          <thead>
            <tr>
              <th>Código</th>
              <th>Nombre</th>
              <th>Nivel</th>
              <th>Personas (Recursivo)</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            <%= for zona <- @zonas do %>
              <tr
                phx-click="toggle_zona"
                phx-value-codigo={zona.codigo}
                style="cursor: pointer; background-color: #f8f9fa;"
              >
                <td style="font-weight: bold; color: #007bff;">
                  {if @zona_expandida == zona.codigo, do: "▼", else: "▶"} {zona.codigo}
                </td>
                <td>{zona.nombre}</td>
                <td>{zona.nivel}</td>
                <td><strong>{zona.personas_afectadas}</strong></td>
                <td>
                  <div phx-click="nada">
                    <button
                      class="btn-accion btn-editar"
                      phx-click="editar"
                      phx-value-codigo={zona.codigo}
                    >Editar</button>
                    <button
                      class="btn-accion btn-eliminar"
                      phx-click="eliminar"
                      phx-value-codigo={zona.codigo}
                      data-confirm="¿Eliminar zona?"
                    >Eliminar</button>
                  </div>
                </td>
              </tr>

              <tr :if={@zona_expandida == zona.codigo}>
                <td colspan="5" style="padding: 0; background-color: #ffffff;">
                  <div style="padding: 1rem; border-left: 4px solid #007bff; margin: 1rem;">
                    <h4 style="margin-top: 0; color: #555;">Detalles de la Zona</h4>

                    <%= if Enum.empty?(zona.sectores) do %>
                      <p style="color: #888; font-style: italic;">
                        No hay sectores ni puntos registrados en esta zona.
                      </p>
                    <% else %>
                      <table style="margin-top: 0; border: 1px solid #eee;">
                        <thead style="background-color: #e9ecef;">
                          <tr>
                            <th>Sector</th>
                            <th>Punto de Atención</th>
                            <th>Personas Afectadas</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for sector <- zona.sectores, punto <- sector.puntos do %>
                            <tr>
                              <td>{sector.nombre}</td>
                              <td>{punto.nombre}</td>
                              <td>{punto.personas_afectadas}</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    <% end %>

                    <hr style="margin: 1.5rem 0;" />
                    <h4 style="margin-top: 0; color: #555;">Asociaciones de la Zona</h4>

                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                      <!-- ALBERGUES -->
                      <div>
                        <strong>Albergues:</strong>
                        <ul style="padding-left: 1.5rem; font-size: 0.9rem;">
                          <%= for a <- Enum.filter(@albergues, &(&1.zona == zona.codigo)) do %>
                            <li>{a.nombre} ({a.ocupacion_actual}/{a.capacidad_maxima})</li>
                          <% end %>
                        </ul>
                      </div>

                      <!-- NECESIDADES -->
                      <div>
                        <strong>Necesidades:</strong>
                        <ul style="padding-left: 1.5rem; font-size: 0.9rem;">
                          <%= for n <- Enum.filter(@necesidades, &(&1.zona == zona.codigo)) do %>
                            <li>{n.tipo} ({n.cantidad_requerida}) - {n.estado}</li>
                          <% end %>
                        </ul>
                      </div>

                      <!-- RECURSOS -->
                      <div>
                        <strong>Recursos:</strong>
                        <ul style="padding-left: 1.5rem; font-size: 0.9rem;">
                          <%= for r <- Enum.filter(@recursos, &(&1.ubicacion == zona.codigo)) do %>
                            <li>{r.nombre} ({r.cantidad} {r.unidad})</li>
                          <% end %>
                        </ul>
                      </div>

                      <!-- PERSONAS -->
                      <div>
                        <strong>Personas Reportadas:</strong>
                        <ul style="padding-left: 1.5rem; font-size: 0.9rem;">
                          <%= for p <- Enum.filter(@personas, &(&1.zona == zona.codigo)) do %>
                            <li>{p.nombre} ({p.estado})</li>
                          <% end %>
                        </ul>
                      </div>

                      <!-- MASCOTAS -->
                      <div>
                        <strong>Mascotas Reportadas:</strong>
                        <ul style="padding-left: 1.5rem; font-size: 0.9rem;">
                          <%= for m <- Enum.filter(@mascotas, &(&1.zona == zona.codigo)) do %>
                            <li>{m.especie} ({m.tipo_reporte})</li>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  </div>
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
