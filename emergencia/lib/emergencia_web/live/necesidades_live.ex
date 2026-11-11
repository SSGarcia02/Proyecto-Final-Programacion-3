defmodule EmergenciaWeb.NecesidadesLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Necesidades
  alias Emergencia.Necesidades.Necesidad
  alias Emergencia.Zonas
  alias Emergencia.Recursos
  alias Emergencia.Usuarios
  alias Emergencia.Personas
  alias Emergencia.Albergues

  @impl true
  def mount(_params, session, socket) do
    tipo = session["tipo"] || "ciudadano"
    username = session["username"] || "desconocido"

    if tipo in ["coordinador", "administrador", "voluntario"] do
      {:ok,
       socket
       |> assign(:necesidades, Necesidades.listar_ordenadas())
       |> assign(:zonas, Zonas.listar())
       |> assign(:recursos, Recursos.listar())
       |> assign(:personas, Personas.listar_personas())
       |> assign(:albergues, Albergues.listar())
       |> assign(:necesidad_expandida, nil)
       |> assign(:necesidad_editando, nil)
       |> assign(:tab_activa, "pendiente")
       |> assign(:username, username)
       |> assign(:filtro_zona, "")
       |> assign(:filtro_tipo, "")
       |> assign(:filtro_prioridad, "")
       |> assign(:error, nil)}
    else
      {:ok, push_navigate(socket, to: "/dashboard")}
    end
  end

  @impl true
  def handle_event("registrar", params, socket) do
    tipo_str = params["tipo"]
    prioridad_str = params["prioridad"]

    with {:ok, tipo} <- Necesidad.parsear_tipo(tipo_str),
         {:ok, prioridad} <- Necesidad.parsear_prioridad(prioridad_str),
         {cantidad, ""} when cantidad > 0 <- Integer.parse(params["cantidad"]) do
      if socket.assigns.necesidad_editando do
        # EDICIÓN
        necesidad_vieja =
          Enum.find(socket.assigns.necesidades, &(&1.id == socket.assigns.necesidad_editando))

        necesidad_actualizada = %{
          necesidad_vieja
          | tipo: tipo,
            cantidad_requerida: cantidad,
            zona: params["zona"],
            prioridad: prioridad,
            descripcion: String.trim(params["descripcion"])
        }

        case Necesidades.actualizar(necesidad_actualizada) do
          {:ok, _} ->
            # <-- REGISTRO DE ACTIVIDAD
            Usuarios.registrar_actividad(
              socket.assigns.username,
              "Actualizó la necesidad #{necesidad_vieja.id}"
            )

            {:noreply,
             socket
             |> assign(:necesidades, Necesidades.listar_ordenadas())
             |> assign(:error, nil)
             |> assign(:necesidad_editando, nil)}

          {:error, _} ->
            {:noreply, assign(socket, :error, "Error al actualizar.")}
        end
      else
        # CREACIÓN
        id = "N" <> Integer.to_string(System.unique_integer([:positive]))

                necesidad = %Necesidad{
          id: id,
          tipo: tipo,
          cantidad_requerida: cantidad,
          zona: params["zona"],
          prioridad: prioridad,
          descripcion: String.trim(params["descripcion"]),
          responsable: socket.assigns.username,
          asociado_a: params["asociado_a"]
        }

        case Necesidades.registrar(necesidad) do
          {:ok, _} ->
            # <-- REGISTRO DE ACTIVIDAD
            Usuarios.registrar_actividad(socket.assigns.username, "Registró la necesidad #{id}")

            {:noreply,
             socket
             |> assign(:necesidades, Necesidades.listar_ordenadas())
             |> assign(:error, nil)}

          {:error, motivo} ->
            {:noreply, assign(socket, :error, "Error: #{motivo}")}
        end
      end
    else
      _ ->
        {:noreply, assign(socket, :error, "Verifica los datos. La cantidad debe ser mayor a 0.")}
    end
  end

  def handle_event(
        "asignar",
        %{"necesidad_id" => id, "recurso" => codigo, "cantidad" => cant_str},
        socket
      ) do
    case Integer.parse(cant_str) do
      {cantidad, ""} when cantidad > 0 ->
        case Necesidades.asignar_recurso(id, codigo, cantidad) do
          {:ok, _} ->
            # <-- REGISTRO DE ACTIVIDAD
            Usuarios.registrar_actividad(
              socket.assigns.username,
              "Asignó recurso #{codigo} a la necesidad #{id}"
            )

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

  def handle_event("toggle_necesidad", %{"id" => id}, socket) do
    if socket.assigns.necesidad_expandida == id do
      {:noreply, assign(socket, :necesidad_expandida, nil)}
    else
      {:noreply, assign(socket, :necesidad_expandida, id)}
    end
  end

  def handle_event("nada", _, socket) do
    {:noreply, socket}
  end

  def handle_event("editar", %{"id" => id}, socket) do
    necesidad = Enum.find(socket.assigns.necesidades, &(&1.id == id))

    if necesidad.estado == "atendida" or necesidad.estado == "cancelada" do
      {:noreply,
       assign(socket, :error, "No se puede editar una necesidad que ya está #{necesidad.estado}.")}
    else
      {:noreply, assign(socket, :necesidad_editando, id)}
    end
  end

  def handle_event("cancelar_edicion", _, socket) do
    {:noreply, assign(socket, :necesidad_editando, nil)}
  end

  def handle_event("cambiar_tab", %{"estado" => estado}, socket) do
    {:noreply, assign(socket, :tab_activa, estado)}
  end

  def handle_event("filtrar", params, socket) do
    {:noreply,
     socket
     |> assign(:filtro_zona, params["zona"] || "")
     |> assign(:filtro_tipo, params["tipo"] || "")
     |> assign(:filtro_prioridad, params["prioridad"] || "")}
  end

  def handle_event("avanzar_estado", %{"id" => id, "estado" => nuevo_estado}, socket) do
    case Necesidades.cambiar_estado(id, nuevo_estado) do
      {:ok, _} ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(
          socket.assigns.username,
          "Cambió estado de necesidad #{id} a #{nuevo_estado}"
        )

        {:noreply,
         socket
         |> assign(:necesidades, Necesidades.listar_ordenadas())
         |> assign(:error, nil)}

      {:error, motivo} ->
        {:noreply, assign(socket, :error, "Error: #{motivo}")}
    end
  end

  def handle_event("cancelar", %{"id" => id}, socket) do
    case Necesidades.cambiar_estado(id, "cancelada") do
      {:ok, _} ->
        # <-- REGISTRO DE ACTIVIDAD
        Usuarios.registrar_actividad(socket.assigns.username, "Canceló la necesidad #{id}")

        {:noreply,
         socket
         |> assign(:necesidades, Necesidades.listar_ordenadas())
         |> assign(:error, nil)}

      {:error, motivo} ->
        {:noreply, assign(socket, :error, "Error: #{motivo}")}
    end
  end

  defp filtrar_necesidades(necesidades, tab, zona, tipo, prioridad) do
    Enum.filter(necesidades, fn n ->
      n.estado == tab and
        (zona == "" or n.zona == zona) and
        (tipo == "" or Atom.to_string(n.tipo) == tipo) and
        (prioridad == "" or Atom.to_string(n.prioridad) == prioridad)
    end)
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
        <h2>{if @necesidad_editando, do: "Editar Necesidad", else: "Registrar Necesidad"}</h2>
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
            <input
              type="number"
              name="cantidad"
              min="1"
              value={
                if @necesidad_editando,
                  do: Enum.find(@necesidades, &(&1.id == @necesidad_editando)).cantidad_requerida,
                  else: 1
              }
              required
            />
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
            <input
              type="text"
              name="descripcion"
              value={
                if @necesidad_editando,
                  do: Enum.find(@necesidades, &(&1.id == @necesidad_editando)).descripcion,
                  else: ""
              }
              placeholder="Ej. Agua para 30 personas"
              required
            />
          </div>

          <!-- SELECTOR DE ASOCIACIÓN -->
          <div style="grid-column: span 2;">
            <label>Asociada a (Persona o Albergue):</label>
            <select name="asociado_a">
              <option value="">Ninguna / General</option>

              <optgroup label="Personas Registradas">
                <%= for p <- @personas do %>
                  <option value={"Persona: " <> p.documento} selected={
                    if @necesidad_editando,
                      do: (Enum.find(@necesidades, &(&1.id == @necesidad_editando)).asociado_a == "Persona: " <> p.documento),
                      else: false
                  }>Persona: {p.nombre} ({p.documento})</option>
                <% end %>
              </optgroup>

              <optgroup label="Albergues">
                <%= for a <- @albergues do %>
                  <option value={"Albergue: " <> a.codigo} selected={
                    if @necesidad_editando,
                      do: (Enum.find(@necesidades, &(&1.id == @necesidad_editando)).asociado_a == "Albergue: " <> a.codigo),
                      else: false
                  }>Albergue: {a.nombre}</option>
                <% end %>
              </optgroup>
            </select>
          </div>

          <div style="grid-column: span 2; margin-top: 1rem; display: flex; gap: 1rem;">
            <button type="submit">{if @necesidad_editando,
              do: "Guardar Cambios",
              else: "Registrar Necesidad"}</button>
            <button
              :if={@necesidad_editando}
              type="button"
              phx-click="cancelar_edicion"
              style="background-color: #6c757d;"
            >Cancelar Edición</button>
          </div>
        </form>
      </div>

      <div class="list-section">
        <h2>Listado de Necesidades</h2>

        <!-- PESTAÑAS DE ESTADO -->
        <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem; flex-wrap: wrap;">
          <%= for estado <- Necesidad.estados() do %>
            <button
              phx-click="cambiar_tab"
              phx-value-estado={estado}
              style={"padding: 0.5rem 1rem; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; " <>
                if @tab_activa == estado,
                  do: "background-color: #007bff; color: white;",
                  else: "background-color: #e9ecef; color: #333;"}
            >
              {String.capitalize(String.replace(estado, "_", " "))}
            </button>
          <% end %>
        </div>

        <!-- BARRA DE FILTROS -->
        <form phx-change="filtrar" style="display: flex; gap: 1rem; margin-bottom: 1rem; background: #f8f9fa; padding: 0.5rem; border-radius: 4px;">
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <span style="font-weight: bold; font-size: 0.9rem;">Zona:</span>
            <select name="zona" style="width: auto; padding: 0.2rem; margin: 0;">
              <option value="">Todas</option>
              <%= for z <- @zonas do %>
                <option value={z.codigo} selected={@filtro_zona == z.codigo}>{z.nombre}</option>
              <% end %>
            </select>
          </div>

          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <span style="font-weight: bold; font-size: 0.9rem;">Tipo:</span>
            <select name="tipo" style="width: auto; padding: 0.2rem; margin: 0;">
              <option value="">Todos</option>
              <%= for t <- Necesidad.tipos() do %>
                <option value={t} selected={@filtro_tipo == Atom.to_string(t)}>{t}</option>
              <% end %>
            </select>
          </div>

          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <span style="font-weight: bold; font-size: 0.9rem;">Prioridad:</span>
            <select name="prioridad" style="width: auto; padding: 0.2rem; margin: 0;">
              <option value="">Todas</option>
              <%= for p <- Necesidad.prioridades() do %>
                <option value={p} selected={@filtro_prioridad == Atom.to_string(p)}>{p}</option>
              <% end %>
            </select>
          </div>
        </form>

        <div style="overflow-x: auto; width: 100%;">
          <table style="white-space: nowrap;">
            <thead>
              <tr>
                <th>ID</th>
                <th>Prioridad</th>
                <th>Tipo</th>
                <th>Cantidad</th>
                <th>Zona</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              <%= for n <- filtrar_necesidades(@necesidades, @tab_activa, @filtro_zona, @filtro_tipo, @filtro_prioridad) do %>
                <tr
                  phx-click="toggle_necesidad"
                  phx-value-id={n.id}
                  style="cursor: pointer; background-color: #f8f9fa;"
                >
                  <td style="font-weight: bold; color: #007bff;">
                    {if @necesidad_expandida == n.id, do: "▼", else: "▶"} {n.id}
                  </td>
                  <td style={"font-weight: bold; color: " <> if n.prioridad == :critica, do: "red", else: "#333"}>
                    {n.prioridad}
                  </td>
                  <td>{n.tipo}</td>
                  <td>{n.cantidad_requerida}</td>
                  <td>{n.zona}</td>
                  <td>
                    <div phx-click="nada" style="display: flex; gap: 0.5rem; align-items: center;">
                      <%= if n.estado == "pendiente" do %>
                        <form
                          phx-submit="asignar"
                          style="display: flex; gap: 0.5rem; align-items: center; margin: 0;"
                        >
                          <input type="hidden" name="necesidad_id" value={n.id} />
                          <select name="recurso" style="width: auto; padding: 0.2rem; margin: 0;">
                            <%= for r <- Enum.filter(@recursos, fn r -> r.categoria == Atom.to_string(n.tipo) end) do %>
                              <option value={r.codigo}>{r.nombre} (Disp: {r.cantidad})</option>
                            <% end %>
                          </select>
                          <input
                            type="number"
                            name="cantidad"
                            value={n.cantidad_requerida}
                            min="1"
                            style="width: 60px; padding: 0.2rem; margin: 0;"
                            required
                          />
                          <button
                            type="submit"
                            style="padding: 0.2rem 0.5rem; font-size: 0.8rem; margin: 0;"
                          >Asignar</button>
                        </form>
                        <button
                          phx-click="cancelar"
                          phx-value-id={n.id}
                          data-confirm="¿Cancelar necesidad?"
                          class="btn-accion btn-eliminar"
                          style="margin: 0;"
                        >Cancelar</button>
                      <% else %>
                        <span style="color: green; font-weight: bold; margin-right: 0.5rem;">✓ {n.recurso_asignado ||
                          "Sin recurso"}</span>

                        <%= if n.estado == "asignada" do %>
                          <button
                            phx-click="avanzar_estado"
                            phx-value-id={n.id}
                            phx-value-estado="en_atencion"
                            class="btn-accion"
                            style="background-color: #17a2b8; margin: 0;"
                          >Poner en Atención</button>
                        <% end %>

                        <%= if n.estado == "en_atencion" do %>
                          <button
                            phx-click="avanzar_estado"
                            phx-value-id={n.id}
                            phx-value-estado="atendida"
                            class="btn-accion"
                            style="background-color: #28a745; margin: 0;"
                          >Marcar Atendida</button>
                        <% end %>

                        <%= if n.estado != "atendida" and n.estado != "cancelada" do %>
                          <button
                            phx-click="cancelar"
                            phx-value-id={n.id}
                            data-confirm="¿Cancelar necesidad?"
                            class="btn-accion btn-eliminar"
                            style="margin: 0;"
                          >Cancelar</button>
                        <% end %>
                      <% end %>
                    </div>
                  </td>
                </tr>

                <tr :if={@necesidad_expandida == n.id}>
                  <td colspan="6" style="padding: 0; background-color: #ffffff;">
                    <div style="padding: 1rem; border-left: 4px solid #007bff; margin: 1rem; white-space: normal;">
                      <h4 style="margin-top: 0; color: #555;">Detalles de la Necesidad</h4>
                      <p>
                        <strong>Estado actual:</strong> {String.capitalize(
                          String.replace(n.estado, "_", " ")
                        )}
                      </p>
                      <p><strong>Descripción:</strong> {n.descripcion}</p>
                      <p><strong>Reportado por:</strong> {n.responsable}</p>
                      <p :if={n.asociado_a}><strong>Asociada a:</strong> {n.asociado_a}</p>
                      <p><strong>Fecha:</strong> {n.fecha_creacion}</p>
                    </div>
                  </td>
                </tr>
              <% end %>

              <%= if Enum.empty?(filtrar_necesidades(@necesidades, @tab_activa, @filtro_zona, @filtro_tipo, @filtro_prioridad)) do %>
                <tr>
                  <td
                    colspan="6"
                    style="text-align: center; padding: 2rem; color: #888; font-style: italic;"
                  >
                    No hay necesidades que coincidan con los filtros en estado "{String.capitalize(@tab_activa)}".
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
