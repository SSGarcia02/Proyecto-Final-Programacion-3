defmodule Emergencia.Albergues do
  use GenServer
  alias Emergencia.Albergues.Albergue

  # ---------- API Pública ----------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar(%Albergue{} = albergue) do
    GenServer.call(__MODULE__, {:registrar, albergue})
  end

  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  def buscar(codigo) do
    GenServer.call(__MODULE__, {:buscar, codigo})
  end

  def ingresar_persona(codigo, documento) do
    GenServer.call(__MODULE__, {:ingresar_persona, codigo, documento})
  end

  def egresar_persona(codigo, documento) do
    GenServer.call(__MODULE__, {:egresar_persona, codigo, documento})
  end

  def eliminar(codigo) do
    GenServer.call(__MODULE__, {:eliminar, codigo})
  end

  def asociar_recurso(codigo_albergue, codigo_recurso) do
    GenServer.call(__MODULE__, {:asociar_recurso, codigo_albergue, codigo_recurso})
  end

  def asociar_necesidad(codigo_albergue, id_necesidad) do
    GenServer.call(__MODULE__, {:asociar_necesidad, codigo_albergue, id_necesidad})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(_opts) do
    case Emergencia.Persistencia.leer_albergues() do
      {:ok, albergues} -> {:ok, albergues}
      {:error, _} -> {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:registrar, albergue}, _from, albergues) do
    if Map.has_key?(albergues, albergue.codigo) do
      {:reply, {:error, :albergue_ya_existe}, albergues}
    else
      nuevos_albergues = Map.put(albergues, albergue.codigo, albergue)
      Emergencia.Persistencia.guardar_albergues(nuevos_albergues)
      {:reply, {:ok, albergue}, nuevos_albergues}
    end
  end

  def handle_call(:listar, _from, albergues) do
    {:reply, Map.values(albergues), albergues}
  end

  def handle_call({:buscar, codigo}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil -> {:reply, {:error, :no_encontrado}, albergues}
      albergue -> {:reply, {:ok, albergue}, albergues}
    end
  end

  def handle_call({:ingresar_persona, codigo, documento}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil ->
        {:reply, {:error, :no_encontrado}, albergues}

      albergue ->
        case Albergue.ingresar(albergue, documento) do
          {:ok, actualizado} ->
            nuevos_albergues = Map.put(albergues, codigo, actualizado)
            Emergencia.Persistencia.guardar_albergues(nuevos_albergues)
            {:reply, {:ok, actualizado}, nuevos_albergues}

          {:error, motivo} ->
            {:reply, {:error, motivo}, albergues}
        end
    end
  end

  def handle_call({:egresar_persona, codigo, documento}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil ->
        {:reply, {:error, :no_encontrado}, albergues}

      albergue ->
        case Albergue.egresar(albergue, documento) do
          {:ok, actualizado} ->
            nuevos_albergues = Map.put(albergues, codigo, actualizado)
            Emergencia.Persistencia.guardar_albergues(nuevos_albergues)
            {:reply, {:ok, actualizado}, nuevos_albergues}

          {:error, motivo} ->
            {:reply, {:error, motivo}, albergues}
        end
    end
  end

  def handle_call({:eliminar, codigo}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil ->
        {:reply, {:error, :no_encontrado}, albergues}

      %{ocupacion_actual: ocupacion} when ocupacion > 0 ->
        {:reply, {:error, :albergue_ocupado}, albergues}

      _albergue ->
        nuevos_albergues = Map.delete(albergues, codigo)
        Emergencia.Persistencia.guardar_albergues(nuevos_albergues)
        {:reply, :ok, nuevos_albergues}
    end
  end

  def handle_call({:asociar_recurso, codigo, codigo_recurso}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil ->
        {:reply, {:error, :no_encontrado}, albergues}

      albergue ->
        if codigo_recurso in albergue.recursos do
          {:reply, {:error, :ya_asociado}, albergues}
        else
          actualizado = %{albergue | recursos: [codigo_recurso | albergue.recursos]}
          nuevos_albergues = Map.put(albergues, codigo, actualizado)
          Emergencia.Persistencia.guardar_albergues(nuevos_albergues)
          {:reply, {:ok, actualizado}, nuevos_albergues}
        end
    end
  end

  def handle_call({:asociar_necesidad, codigo, id_necesidad}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil ->
        {:reply, {:error, :no_encontrado}, albergues}

      albergue ->
        if id_necesidad in albergue.necesidades do
          {:reply, {:error, :ya_asociado}, albergues}
        else
          actualizado = %{albergue | necesidades: [id_necesidad | albergue.necesidades]}
          nuevos_albergues = Map.put(albergues, codigo, actualizado)
          Emergencia.Persistencia.guardar_albergues(nuevos_albergues)
          {:reply, {:ok, actualizado}, nuevos_albergues}
        end
    end
  end
end
