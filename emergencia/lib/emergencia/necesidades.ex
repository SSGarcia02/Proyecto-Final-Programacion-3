defmodule Emergencia.Necesidades do
  @moduledoc """
  GenServer que administra el ciclo de vida de las necesidades (solicitudes de ayuda)
  en el sistema de emergencias.

  Este módulo mantiene en memoria el mapa de necesidades, valida las transiciones
  de estado, coordina la asignación de recursos con el GenServer de Recursos y
  persiste los cambios en `data/necesidades.csv`.

  Reglas de negocio importantes:
  - Una necesidad recién creada siempre inicia en estado `"pendiente"`.
  - Solo las necesidades en estado `"pendiente"` pueden recibir una asignación
    de recursos.
  - Al asignar un recurso, se descuenta del inventario y la necesidad pasa a
    `"asignada"`.
  - Si una necesidad con recurso asignado se cancela, el recurso se devuelve
    automáticamente al inventario.
  """

  use GenServer
  alias Emergencia.Necesidades.Necesidad

  # ---------- API Pública ----------

  @doc """
  Inicia el GenServer y registra el proceso con el nombre `Emergencia.Necesidades`.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registra una nueva necesidad.

  El estado inicial siempre es `"pendiente"` y se le asigna automáticamente la
  fecha de creación actual.

  ## Retorna
  - `{:ok, necesidad}` si se registra correctamente.
  - `{:error, :id_duplicado}` si ya existe una necesidad con ese ID.
  """
  def registrar(%Necesidad{} = necesidad) do
    GenServer.call(__MODULE__, {:registrar, necesidad})
  end

  @doc """
  Devuelve la lista de necesidades ordenadas por prioridad y fecha de creación.

  Las de prioridad `:critica` aparecen primero, seguidas de `:alta`, `:media` y
  `:baja`. Dentro de la misma prioridad, se ordenan por fecha (las más antiguas
  primero).
  """
  def listar_ordenadas do
    GenServer.call(__MODULE__, :listar_ordenadas)
  end

  @doc """
  Busca una necesidad por su ID.

  ## Retorna
  - `{:ok, necesidad}` si existe.
  - `{:error, :no_encontrada}` en caso contrario.
  """
  def buscar(id) do
    GenServer.call(__MODULE__, {:buscar, id})
  end

  @doc """
  Asigna un recurso a una necesidad pendiente.

  Realiza las siguientes validaciones:
  1. La necesidad debe existir y no estar `"atendida"` ni `"cancelada"`.
  2. El recurso debe existir y su categoría debe coincidir con el tipo de necesidad.
  3. Debe haber suficientes existencias en el inventario.

  Si todo es correcto, descuenta la cantidad del recurso, cambia el estado de la
  necesidad a `"asignada"` y guarda el código del recurso asignado.

  ## Retorna
  - `{:ok, necesidad_actualizada}` si la asignación es exitosa.
  - `{:error, :necesidad_no_encontrada}` si la necesidad no existe.
  - `{:error, :estado_no_valido_para_asignar}` si ya está atendida o cancelada.
  - `{:error, :tipo_incompatible}` si la categoría del recurso no coincide.
  - `{:error, :sin_existencias}` si no hay suficientes unidades.
  - `{:error, :recurso_no_encontrado}` si el recurso no existe.
  """
  def asignar_recurso(id_necesidad, codigo_recurso, cantidad) do
    GenServer.call(__MODULE__, {:asignar_recurso, id_necesidad, codigo_recurso, cantidad})
  end

  @doc """
  Elimina una necesidad del sistema.
  """
  def eliminar(id) do
    GenServer.call(__MODULE__, {:eliminar, id})
  end

  @doc """
  Actualiza los datos de una necesidad existente (sin cambiar su estado).
  """
  def actualizar(%Necesidad{} = necesidad) do
    GenServer.call(__MODULE__, {:actualizar, necesidad})
  end

  @doc """
  Cambia el estado de una necesidad.

  Si el nuevo estado es `"cancelada"` y la necesidad tenía un recurso asignado,
  el recurso se devuelve automáticamente al inventario.

  ## Retorna
  - `{:ok, necesidad_actualizada}` si el cambio es exitoso.
  - `{:error, :no_encontrada}` si la necesidad no existe.
  - `{:error, :estado_invalido}` si el estado no es válido.
  """
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
        if Necesidad.estado_valido?(nuevo_estado) do
          # Si se está cancelando y tiene un recurso asignado, lo devolvemos
          if nuevo_estado == "cancelada" and necesidad.recurso_asignado != nil do
            devolver_recurso(necesidad.recurso_asignado)
          end

          nec_actualizada = %{necesidad | estado: nuevo_estado}
          nuevas_necesidades = Map.put(necesidades, id, nec_actualizada)
          Emergencia.Persistencia.guardar_necesidades(nuevas_necesidades)
          {:reply, {:ok, nec_actualizada}, nuevas_necesidades}
        else
          {:reply, {:error, :estado_invalido}, necesidades}
        end
    end
  end

  # Función auxiliar para extraer la cantidad del string y sumarla al inventario
  defp devolver_recurso(recurso_asignado) do
    # Separamos el string por el paréntesis: "R001 (30)" -> ["R001 ", "30)"]
    case String.split(recurso_asignado, "(") do
      [codigo_con_espacio, cantidad_con_parentesis] ->
        codigo_recurso = String.trim(codigo_con_espacio)
        cantidad_str = String.replace(cantidad_con_parentesis, ")", "")

        case Integer.parse(cantidad_str) do
          {cantidad, _} ->
            # Llamamos al GenServer de Recursos para sumar la cantidad
            Emergencia.Recursos.ingresar(codigo_recurso, cantidad)

          :error ->
            :ok
        end

      _ ->
        :ok
    end
  end
end
