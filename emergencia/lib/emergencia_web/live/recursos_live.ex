defmodule EmergenciaWeb.RecursosLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.Recursos
  alias Emergencia.Recursos.Recurso

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:recursos, Recursos.listar())
     |> assign(:error, nil)
     |> assign(:recurso_editando, nil)}
  end

  @impl true
  def handle_event("registrar", params, socket) do
    codigo = String.trim(params["codigo"])
    nombre = String.trim(params["nombre"])
    categoria = String.trim(params["categoria"])
    unidad = String.trim(params["unidad"])
    ubicacion = String.trim(params["ubicacion"])

    case Integer.parse(params["cantidad"]) do
      {cantidad, ""} when cantidad >= 0 ->
        recurso = %Recurso{
          codigo: codigo,
          nombre: nombre,
          categoria: categoria,
          unidad: unidad,
          ubicacion: ubicacion,
          cantidad: cantidad
        }

        resultado =
          if socket.assigns.recurso_editando do
            # Al editar, conservamos el historial de movimientos
            recurso_viejo = Enum.find(socket.assigns.recursos, &(&1.codigo == socket.assigns.recurso_editando))
            recurso_actualizado = %{recurso | historial: recurso_viejo.historial}

            # Si cambió el código, borramos el viejo y creamos el nuevo
            Recursos.eliminar(socket.assigns.recurso_editando)
            Recursos.registrar(recurso_actualizado)
          else
            Recursos.registrar(recurso)
          end

        case resultado do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:recursos, Recursos.listar())
             |> assign(:error, nil)
             |> assign(:recurso_editando, nil)}

          {:error, :recurso_ya_existe} ->
            {:noreply, assign(socket, :error, "Ya existe un recurso con ese código.")}
        end

      _ ->
        {:noreply, assign(socket, :error, "La cantidad debe ser un número entero mayor o igual a 0.")}
    end
  end

  @impl true
  def handle_event("eliminar", %{"codigo" => codigo}, socket) do
    Recursos.eliminar(codigo)
    {:noreply,
     socket
     |> assign(:recursos, Recursos.listar())
     |> assign(:error, nil)
     |> assign(:recurso_editando, nil)}
  end

  def handle_event("editar", %{"codigo" => codigo}, socket) do
    {:noreply, assign(socket, :recurso_editando, codigo)}
  end

  def handle_event("cancelar_edicion", _, socket) do
    {:noreply, assign(socket, :recurso_editando, nil)}
  end

  @impl true
  def handle_event("movimiento", %{"codigo" => codigo, "tipo" => tipo, "cantidad" => cant_str}, socket) do
    case Integer.parse(cant_str) do
      {cantidad, ""} when cantidad > 0 ->
        resultado =
          if tipo == "entrada" do
            Recursos.ingresar(codigo, cantidad)
          else
            Recursos.egresar(codigo, cantidad)
          end

        case resultado do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:recursos, Recursos.listar())
             |> assign(:error, nil)}

          {:error, :sin_existencias} ->
            {:noreply, assign(socket, :error, "No hay suficientes existencias para esa salida.")}

          {:error, :no_encontrado} ->
            {:noreply, assign(socket, :error, "Recurso no encontrado.")}
        end

      _ ->
        {:noreply, assign(socket, :error, "La cantidad debe ser un número entero mayor a 0.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="recursos-container">
      <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
        <h1>Inventario de Recursos</h1>
        <a href="/dashboard" style="text-decoration: none; color: #007bff; font-weight: bold;">← Volver al Dashboard</a>
      </header>

      <div :if={@error} class="error"><%= @error %></div>

      <div class="form-section">
        <h2><%= if @recurso_editando, do: "Editar Recurso", else: "Registrar Nuevo Recurso" %></h2>
        <form phx-submit="registrar" style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
          <div>
            <label>Código:</label>
            <input type="text" name="codigo" value={@recurso_editando} required />
          </div>
          <div>
            <label>Nombre:</label>
            <input type="text" name="nombre" value={
              if @recurso_editando, do: Enum.find(@recursos, &(&1.codigo == @recurso_editando)).nombre, else: ""
            } required />
          </div>
          <div>
            <label>Categoría:</label>
            <input type="text" name="categoria" value={
              if @recurso_editando, do: Enum.find(@recursos, &(&1.codigo == @recurso_editando)).categoria, else: ""
            } required />
          </div>
          <div>
            <label>Unidad de medida:</label>
            <input type="text" name="unidad" value={
              if @recurso_editando, do: Enum.find(@recursos, &(&1.codigo == @recurso_editando)).unidad, else: ""
            } required />
          </div>
          <div>
            <label>Ubicación:</label>
            <input type="text" name="ubicacion" value={
              if @recurso_editando, do: Enum.find(@recursos, &(&1.codigo == @recurso_editando)).ubicacion, else: ""
            } required />
          </div>
          <div>
            <label>Cantidad inicial:</label>
            <input type="number" name="cantidad" value={
              if @recurso_editando, do: Enum.find(@recursos, &(&1.codigo == @recurso_editando)).cantidad, else: 0
            } min="0" required />
          </div>

          <div style="grid-column: span 2; display: flex; gap: 1rem; margin-top: 1rem;">
            <button type="submit"><%= if @recurso_editando, do: "Guardar Cambios", else: "Registrar Recurso" %></button>
            <button :if={@recurso_editando} type="button" phx-click="cancelar_edicion" style="background-color: #6c757d;">Cancelar</button>
          </div>
        </form>
      </div>

      <div class="list-section">
        <h2>Recursos en Inventario</h2>
        <table>
          <thead>
            <tr>
              <th>Código</th>
              <th>Nombre</th>
              <th>Ubicación</th>
              <th>Cantidad</th>
              <th>Movimiento</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={r <- @recursos}>
              <td><%= r.codigo %></td>
              <td><%= r.nombre %> (<%= r.categoria %>)</td>
              <td><%= r.ubicacion %></td>
              <td><strong><%= r.cantidad %></strong> <%= r.unidad %></td>
              <td>
                <form phx-submit="movimiento" style="display: flex; gap: 0.5rem;">
                  <input type="hidden" name="codigo" value={r.codigo} />
                  <select name="tipo">
                    <option value="entrada">+ Entrada</option>
                    <option value="salida">- Salida</option>
                  </select>
                  <input type="number" name="cantidad" min="1" placeholder="Cant." style="width: 70px;" required />
                  <button type="submit" style="padding: 0.2rem 0.5rem; font-size: 0.8rem;">Aplicar</button>
                </form>
              </td>
              <td>
                <button class="btn-accion btn-editar" phx-click="editar" phx-value-codigo={r.codigo}>Editar</button>
                <button class="btn-accion btn-eliminar" phx-click="eliminar" phx-value-codigo={r.codigo} data-confirm="¿Eliminar recurso?">Eliminar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
