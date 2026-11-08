defmodule Emergencia.Necesidades do
  use GenServer
  alias Emergencia.Necesidades.Necesidad

  # ---------- API Pública ----------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar(%Necesidad{} = necesidad) do
    GenServer.call(__MODULE__, {:registrar, necesidad})
  end

  def listar_ordenadas do
    GenServer.call(__MODULE__, :listar_ordenadas)
  end

  def buscar(id) do
    GenServer.call(__MODULE__, {:buscar, id})
  end

  def asignar_recurso(id_necesidad, codigo_recurso, cantidad) do
    GenServer.call(__MODULE__, {:asignar_recurso, id_necesidad, codigo_recurso, cantidad})
  end

  def eliminar(id) do
    GenServer.call(__MODULE__, {:eliminar, id})
  end

  def actualizar(%Necesidad{} = necesidad) do
    GenServer.call(__MODULE__, {:actualizar, necesidad})
  end

  def cambiar_estado(id, nuevo_estado) do
    GenServer.call(__MODULE__, {:cambiar_estado, id, nuevo_estado})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(_opts) do
    case Emergencia.Persistencia.leer_necesidades() do
      {:ok, necesidades} -> {:ok, necesidades}
      {:error, _} -> {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:registrar, necesidad}, _from, necesidades) do
    if Map.has_key?(necesidades, necesidad.id) do
      {:reply, {:error, :id_duplicado}, necesidades}
    else
      nueva_necesidad = %{
        necesidad
        | estado: "pendiente",
          fecha_creacion: DateTime.utc_now() |> DateTime.to_string()
      }

      nuevas_necesidades = Map.put(necesidades, necesidad.id, nueva_necesidad)
      Emergencia.Persistencia.guardar_necesidades(nuevas_necesidades)

      {:reply, {:ok, nueva_necesidad}, nuevas_necesidades}
    end
  end

  def handle_call(:listar_ordenadas, _from, necesidades) do
    lista =
      necesidades
      |> Map.values()
      |> Enum.sort_by(fn n -> {Necesidad.peso_prioridad(n.prioridad), n.fecha_creacion} end)

    {:reply, lista, necesidades}
  end

  def handle_call({:buscar, id}, _from, necesidades) do
    case Map.get(necesidades, id) do
      nil -> {:reply, {:error, :no_encontrada}, necesidades}
      nec -> {:reply, {:ok, nec}, necesidades}
    end
  end

  def handle_call({:asignar_recurso, id, codigo_recurso, cantidad}, _from, necesidades) do
    case Map.get(necesidades, id) do
      nil ->
        {:reply, {:error, :necesidad_no_encontrada}, necesidades}

      # Si ya está atendida o cancelada, no se le pueden asignar más cosas
      %{estado: estado} when estado in ["atendida", "cancelada"] ->
        {:reply, {:error, :estado_no_valido_para_asignar}, necesidades}

      necesidad ->
        # 1. Verificamos que el recurso exista y coincida con el tipo de necesidad
        case Emergencia.Recursos.buscar(codigo_recurso) do
          {:ok, recurso} ->
            if recurso.categoria == Atom.to_string(necesidad.tipo) do
              # 2. Intentamos egresar el recurso del inventario
              case Emergencia.Recursos.egresar(codigo_recurso, cantidad) do
                {:ok, _recurso_actualizado} ->
                  # 3. Si se descuenta bien, pasa a estado "asignada" (no a atendida)
                  nec_actualizada = %{
                    necesidad
                    | estado: "asignada",
                      recurso_asignado: "#{codigo_recurso} (#{cantidad})"
                  }

                  nuevas_necesidades = Map.put(necesidades, id, nec_actualizada)
                  Emergencia.Persistencia.guardar_necesidades(nuevas_necesidades)

                  {:reply, {:ok, nec_actualizada}, nuevas_necesidades}

                {:error, motivo} ->
                  # Si no hay suficientes recursos, no cambiamos nada
                  {:reply, {:error, motivo}, necesidades}
              end
            else
              {:reply, {:error, :tipo_incompatible}, necesidades}
            end

          {:error, _} ->
            {:reply, {:error, :recurso_no_encontrado}, necesidades}
        end
    end
  end

  def handle_call({:eliminar, id}, _from, necesidades) do
    if Map.has_key?(necesidades, id) do
      nuevas_necesidades = Map.delete(necesidades, id)
      Emergencia.Persistencia.guardar_necesidades(nuevas_necesidades)
      {:reply, :ok, nuevas_necesidades}
    else
      {:reply, {:error, :no_encontrada}, necesidades}
    end
  end

  def handle_call({:actualizar, necesidad}, _from, necesidades) do
    if Map.has_key?(necesidades, necesidad.id) do
      nuevas_necesidades = Map.put(necesidades, necesidad.id, necesidad)
      Emergencia.Persistencia.guardar_necesidades(nuevas_necesidades)
      {:reply, {:ok, necesidad}, nuevas_necesidades}
    else
      {:reply, {:error, :no_encontrada}, necesidades}
    end
  end

  def handle_call({:cambiar_estado, id, nuevo_estado}, _from, necesidades) do
    case Map.get(necesidades, id) do
      nil ->
        {:reply, {:error, :no_encontrada}, necesidades}

      necesidad ->
        # Validar que el estado sea válido
        if Necesidad.estado_valido?(nuevo_estado) do
          nec_actualizada = %{necesidad | estado: nuevo_estado}
          nuevas_necesidades = Map.put(necesidades, id, nec_actualizada)
          Emergencia.Persistencia.guardar_necesidades(nuevas_necesidades)
          {:reply, {:ok, nec_actualizada}, nuevas_necesidades}
        else
          {:reply, {:error, :estado_invalido}, necesidades}
        end
    end
  end
end
