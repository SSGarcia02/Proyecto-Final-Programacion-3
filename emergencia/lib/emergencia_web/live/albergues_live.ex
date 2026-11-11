defmodule EmergenciaWeb.AlberguesLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Albergues
  alias Emergencia.Albergues.Albergue
  alias Emergencia.Zonas
  alias Emergencia.Recursos
  alias Emergencia.Necesidades
  # <-- NUEVO ALIAS
  alias Emergencia.Usuarios

  @impl true
  def mount(_params, session, socket) do
    tipo = session["tipo"] || "ciudadano"
    username = session["username"] || "desconocido"

    if tipo in ["coordinador", "administrador", "voluntario"] do
      {:ok,
       socket
       |> assign(:albergues, Albergues.listar())
       |> assign(:zonas, Zonas.listar())
       |> assign(:recursos, Recursos.listar())
       |> assign(:necesidades, Necesidades.listar_ordenadas())
       |> assign(:albergue_expandido, nil)
       |> assign(:username, username)
       |> assign(:error, nil)}
    else
      {:ok, push_navigate(socket, to: "/dashboard")}
    end
  end

  @impl true
  def handle_event("registrar", params, socket) do
    codigo = String.trim(params["codigo"])
    nombre = String.trim(params["nombre"])

    case Integer.parse(params["capacidad"]) do
      {capacidad, ""} when capacidad > 0 ->
        albergue = %Albergue{
          codigo: codigo,
          nombre: nombre,
          zona: params["zona"],
          capacidad_maxima: capacidad
        }

        case Albergues.registrar(albergue) do
          {:ok, _} ->
            # <-- REGISTRO DE ACTIVIDAD
            Usuarios.registrar_actividad(
              socket.assigns.username,
              "Registró el albergue #{codigo}"
            )

            {:noreply,
             socket
             |> assign(:albergues, Albergues.listar())
             |> assign(:error, nil)}

          {:error, :albergue_ya_existe} ->
            {:noreply, assign(socket, :error, "Ya existe un albergue con ese código.")}
        end

      _ ->
        {:noreply, assign(socket, :error, "La capacidad debe ser un número entero mayor a 0.")}
    end
  end

  def handle_event("eliminar", %{"codigo" => codigo}, socket) do
    case Albergues.eliminar(codigo) do
      :ok ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(socket.assigns.username, "Eliminó el albergue #{codigo}")
        {:noreply, assign(socket, albergues: Albergues.listar(), error: nil)}

      {:error, :albergue_ocupado} ->
        {:noreply,
         assign(socket, :error, "No se puede eliminar un albergue con personas dentro.")}
    end
  end

  def handle_event("toggle_albergue", %{"codigo" => codigo}, socket) do
    if socket.assigns.albergue_expandido == codigo do
      {:noreply, assign(socket, :albergue_expandido, nil)}
    else
      {:noreply, assign(socket, :albergue_expandido, codigo)}
    end
  end

  def handle_event("nada", _, socket) do
    {:noreply, socket}
  end

  def handle_event("ingresar", %{"codigo" => codigo, "documento" => documento}, socket) do
    documento = String.trim(documento)

    case Albergues.ingresar_persona(codigo, documento) do
      {:ok, _} ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(
          socket.assigns.username,
          "Registró ingreso de #{documento} al albergue #{codigo}"
        )

        {:noreply,
         socket
         |> assign(:albergues, Albergues.listar())
         |> assign(:error, nil)}

      {:error, :sin_cupo} ->
        {:noreply, assign(socket, :error, "El albergue está lleno (capacidad máxima alcanzada).")}

      {:error, :ya_esta_en_albergue} ->
        {:noreply, assign(socket, :error, "Esa persona ya está registrada en este albergue.")}

      _ ->
        {:noreply, assign(socket, :error, "Error al ingresar.")}
    end
  end

  def handle_event("egresar", %{"codigo" => codigo, "documento" => documento}, socket) do
    documento = String.trim(documento)

    case Albergues.egresar_persona(codigo, documento) do
      {:ok, _} ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(
          socket.assigns.username,
          "Registró salida de #{documento} del albergue #{codigo}"
        )

        {:noreply,
         socket
         |> assign(:albergues, Albergues.listar())
         |> assign(:error, nil)}

      {:error, :no_esta_en_albergue} ->
        {:noreply, assign(socket, :error, "Esa persona no está registrada en este albergue.")}

      _ ->
        {:noreply, assign(socket, :error, "Error al egresar.")}
    end
  end

  def handle_event("asociar_recurso", %{"codigo" => codigo, "recurso" => rec_codigo}, socket) do
    case Albergues.asociar_recurso(codigo, rec_codigo) do
      {:ok, _} ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(
          socket.assigns.username,
          "Asoció recurso #{rec_codigo} al albergue #{codigo}"
        )

        {:noreply, assign(socket, :albergues, Albergues.listar())}

      {:error, :ya_asociado} ->
        {:noreply, assign(socket, :error, "Ese recurso ya está asociado.")}

      _ ->
        {:noreply, assign(socket, :error, "Error al asociar recurso.")}
    end
  end

  def handle_event("asociar_necesidad", %{"codigo" => codigo, "necesidad" => id_nec}, socket) do
    case Albergues.asociar_necesidad(codigo, id_nec) do
      {:ok, _} ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(
          socket.assigns.username,
          "Asoció necesidad #{id_nec} al albergue #{codigo}"
        )

        {:noreply, assign(socket, :albergues, Albergues.listar())}

      {:error, :ya_asociado} ->
        {:noreply, assign(socket, :error, "Esa necesidad ya está asociada.")}

      _ ->
        {:noreply, assign(socket, :error, "Error al asociar necesidad.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <h1>Gestión de Albergues</h1>
        <a href="/dashboard" style="text-decoration: none; color: #007bff; font-weight: bold;">← Volver al Dashboard</a>
      </header>

      <div :if={@error} class="error">{@error}</div>

      <!-- REPORTE DE OCUPACIÓN CON BARRA DE PROGRESO -->
      <div
        class="list-section"
        style="background-color: #e9ecef; display: grid; grid-template-columns: 1fr 1fr; gap: 2rem;"
      >
        <div>
          <h3 style="margin-top: 0; color: #333;">Albergues con Mayor Ocupación</h3>
          <ul style="margin: 0; padding-left: 1.5rem;">
            <%= for a <- Enum.take(Enum.sort_by(@albergues, &Albergue.porcentaje_ocupacion/1, :desc), 3) do %>
              <li>
                <strong>{a.nombre}</strong>
                - {Float.round(Albergue.porcentaje_ocupacion(a), 1)}% ({a.ocupacion_actual}/{a.capacidad_maxima})
              </li>
            <% end %>
          </ul>
        </div>

        <div style="display: flex; align-items: center;">
          <div style="width: 100%;">
            <p style="margin: 0 0 0.5rem 0; font-size: 0.9rem; color: #555;">
              Ocupación Global del Sistema
            </p>

            <% total_capacidad = Enum.sum(Enum.map(@albergues, & &1.capacidad_maxima))
            total_ocupacion = Enum.sum(Enum.map(@albergues, & &1.ocupacion_actual))

            porcentaje_global =
              if total_capacidad > 0, do: total_ocupacion / total_capacidad * 100, else: 0.0 %>

            <div style="width: 100%; background-color: #ccc; border-radius: 4px; height: 20px;">
              <div style={"width: #{porcentaje_global}%; background-color: #007bff; height: 20px; border-radius: 4px; text-align: center; color: white; font-size: 0.8rem; line-height: 20px;"}>
                {Float.round(porcentaje_global, 1)}%
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="form-section">
        <h2>Registrar Albergue</h2>
        <form phx-submit="registrar" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
          <div>
            <label>Código:</label>
            <input type="text" name="codigo" placeholder="Ej. A01" required />
          </div>
          <div>
            <label>Nombre:</label>
            <input type="text" name="nombre" placeholder="Ej. Albergue Norte" required />
          </div>
          <div>
            <label>Zona:</label>
            <select name="zona">
              <%= for z <- @zonas do %>
                <option value={z.codigo}>{z.codigo} - {z.nombre}</option>
              <% end %>
            </select>
          </div>
          <div>
            <label>Capacidad Máxima:</label>
            <input type="number" name="capacidad" min="1" value="50" required />
          </div>
          <div style="grid-column: span 2; margin-top: 1rem;">
            <button type="submit">Registrar Albergue</button>
          </div>
        </form>
      </div>

      <div class="list-section">
        <h2>Albergues Registrados</h2>

        <div style="overflow-x: auto; width: 100%;">
          <table style="white-space: nowrap;">
            <thead>
              <tr>
                <th>Código</th>
                <th>Nombre</th>
                <th>Zona</th>
                <th>Ocupación</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              <%= for a <- @albergues do %>
                <tr
                  phx-click="toggle_albergue"
                  phx-value-codigo={a.codigo}
                  style="cursor: pointer; background-color: #f8f9fa;"
                >
                  <td style="font-weight: bold; color: #007bff;">
                    {if @albergue_expandido == a.codigo, do: "▼", else: "▶"} {a.codigo}
                  </td>
                  <td>{a.nombre}</td>
                  <td>
                    {case Enum.find(@zonas, &(&1.codigo == a.zona)) do
                      nil -> a.zona
                      z -> z.nombre
                    end}
                  </td>
                  <td>
                    <strong>{a.ocupacion_actual}</strong> / {a.capacidad_maxima}
                  </td>
                  <td>
                    <div phx-click="nada">
                      <%= if a.ocupacion_actual == 0 do %>
                        <button
                          class="btn-accion btn-eliminar"
                          phx-click="eliminar"
                          phx-value-codigo={a.codigo}
                          data-confirm="¿Eliminar albergue?"
                        >Eliminar</button>
                      <% else %>
                        <span style="color: #888; font-size: 0.8rem;">En uso</span>
                      <% end %>
                    </div>
                  </td>
                </tr>

                <tr :if={@albergue_expandido == a.codigo}>
                  <td colspan="5" style="padding: 0; background-color: #ffffff;">
                    <div style="padding: 1rem; border-left: 4px solid #007bff; margin: 1rem; white-space: normal;">
                      <h4 style="margin-top: 0; color: #555;">Gestión de Personas</h4>

                      <div style="display: flex; gap: 2rem; margin-bottom: 1rem;">
                        <form
                          phx-submit="ingresar"
                          style="display: flex; gap: 0.5rem; align-items: center;"
                        >
                          <input type="hidden" name="codigo" value={a.codigo} />
                          <input
                            type="text"
                            name="documento"
                            placeholder="Documento"
                            required
                            style="padding: 0.2rem;"
                          />
                          <button type="submit" style="padding: 0.2rem 0.5rem; font-size: 0.8rem;">Registrar Ingreso</button>
                        </form>

                        <form
                          phx-submit="egresar"
                          style="display: flex; gap: 0.5rem; align-items: center;"
                        >
                          <input type="hidden" name="codigo" value={a.codigo} />
                          <input
                            type="text"
                            name="documento"
                            placeholder="Documento"
                            required
                            style="padding: 0.2rem;"
                          />
                          <button
                            type="submit"
                            style="padding: 0.2rem 0.5rem; font-size: 0.8rem; background-color: #6c757d;"
                          >Registrar Salida</button>
                        </form>
                      </div>

                      <% cupos = a.capacidad_maxima - a.ocupacion_actual %>
                      <p>
                        <strong>Cupos disponibles:</strong>
                        <span style={"font-weight: bold; color: #{if cupos == 0, do: "red", else: "green"};"}>
                          {cupos}
                        </span>
                      </p>

                      <h5 style="margin-bottom: 0.5rem;">
                        Personas alojadas ({a.ocupacion_actual}):
                      </h5>
                      <%= if Enum.empty?(a.personas) do %>
                        <p style="color: #888; font-style: italic;">No hay personas registradas.</p>
                      <% else %>
                        <ul style="margin: 0; padding-left: 1.5rem;">
                          <%= for doc <- a.personas do %>
                            <li>{doc}</li>
                          <% end %>
                        </ul>
                      <% end %>

                      <hr style="margin: 1.5rem 0;" />

                      <h4 style="margin-top: 0; color: #555;">Recursos y Necesidades Asociadas</h4>

                      <div style="display: flex; gap: 2rem; margin-bottom: 1rem;">
                        <form
                          phx-submit="asociar_recurso"
                          style="display: flex; gap: 0.5rem; align-items: center;"
                        >
                          <input type="hidden" name="codigo" value={a.codigo} />
                          <select name="recurso" style="width: auto; padding: 0.2rem;">
                            <%= for r <- @recursos do %>
                              <option value={r.codigo}>{r.nombre}</option>
                            <% end %>
                          </select>
                          <button
                            type="submit"
                            style="padding: 0.2rem 0.5rem; font-size: 0.8rem; background-color: #17a2b8;"
                          >Asociar Recurso</button>
                        </form>

                        <form
                          phx-submit="asociar_necesidad"
                          style="display: flex; gap: 0.5rem; align-items: center;"
                        >
                          <input type="hidden" name="codigo" value={a.codigo} />
                          <select name="necesidad" style="width: auto; padding: 0.2rem;">
                            <%= for n <- @necesidades do %>
                              <option value={n.id}>{n.id} - {n.tipo}</option>
                            <% end %>
                          </select>
                          <button
                            type="submit"
                            style="padding: 0.2rem 0.5rem; font-size: 0.8rem; background-color: #17a2b8;"
                          >Asociar Necesidad</button>
                        </form>
                      </div>

                      <div style="display: flex; gap: 2rem;">
                        <div>
                          <strong>Recursos Asociados:</strong>
                          <ul style="margin: 0.5rem 0 0 0; padding-left: 1.5rem;">
                            <%= for rec_codigo <- a.recursos do %>
                              <li>
                                {case Enum.find(@recursos, &(&1.codigo == rec_codigo)) do
                                  nil -> rec_codigo
                                  r -> "#{r.nombre} (#{r.codigo})"
                                end}
                              </li>
                            <% end %>
                          </ul>
                        </div>
                        <div>
                          <strong>Necesidades Asociadas:</strong>
                          <ul style="margin: 0.5rem 0 0 0; padding-left: 1.5rem;">
                            <%= for nec_id <- a.necesidades do %>
                              <li>
                                {case Enum.find(@necesidades, &(&1.id == nec_id)) do
                                  nil -> nec_id
                                  n -> "#{n.tipo} - ID: #{n.id}"
                                end}
                              </li>
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
    </div>
    """
  end
end
