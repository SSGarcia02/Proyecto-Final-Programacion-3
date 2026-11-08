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

      %{estado: "atendida"} ->
        {:reply, {:error, :ya_atendida}, necesidades}

      necesidad ->
        # 1. Verificamos que el recurso exista y coincida con el tipo de necesidad
        case Emergencia.Recursos.buscar(codigo_recurso) do
          {:ok, recurso} ->
            if recurso.categoria == Atom.to_string(necesidad.tipo) do
              # 2. Intentamos egresar el recurso del inventario
              case Emergencia.Recursos.egresar(codigo_recurso, cantidad) do
                {:ok, _recurso_actualizado} ->
                  # 3. Si el recurso se descontó con éxito, actualizamos la necesidad
                  nec_actualizada = %{
                    necesidad
                    | estado: "atendida",
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
end
