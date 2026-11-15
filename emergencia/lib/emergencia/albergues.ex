defmodule Emergencia.Albergues do
  @moduledoc """
  GenServer que administra el estado de los albergues temporales.

  Este módulo es el encargado de mantener en memoria el mapa de albergues, de
  procesar las peticiones de forma concurrente y de persistir los cambios en el
  archivo `data/albergues.csv`.

  Además de gestionar el ciclo de vida de un albergue (registro, búsqueda,
  eliminación), este GenServer se encarga de:
  - Validar que una persona exista antes de ingresarla a un albergue.
  - Sincronizar el estado de la persona (a `"en_albergue"` al ingresar y a
    `"reportada"` al egresar) llamando al GenServer de Personas.
  - Impedir la eliminación de un albergue si tiene personas alojadas.
  """

  use GenServer
  alias Emergencia.Albergues.Albergue

  # ---------- API Pública ----------

  @doc """
  Inicia el GenServer y registra el proceso con el nombre `Emergencia.Albergues`.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registra un albergue nuevo en el sistema.

  Valida que no exista otro albergue con el mismo código. Si es válido, lo
  persiste en el CSV.

  ## Retorna
  - `{:ok, albergue}` si se registra correctamente.
  - `{:error, :albergue_ya_existe}` si ya hay uno con ese código.
  """
  def registrar(%Albergue{} = albergue) do
    GenServer.call(__MODULE__, {:registrar, albergue})
  end

  @doc """
  Devuelve la lista de todos los albergues registrados.
  """
  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  @doc """
  Busca un albergue por su código.

  ## Retorna
  - `{:ok, albergue}` si existe.
  - `{:error, :no_encontrado}` en caso contrario.
  """
  def buscar(codigo) do
    GenServer.call(__MODULE__, {:buscar, codigo})
  end

  @doc """
  Registra el ingreso de una persona a un albergue.

  Valida que la persona exista en el sistema y que el albergue tenga cupo.
  Si todo es correcto, actualiza la ocupación del albergue y cambia el estado
  de la persona a `"en_albergue"`.

  ## Retorna
  - `{:ok, albergue_actualizado}` si el ingreso es exitoso.
  - `{:error, :persona_no_registrada}` si la persona no existe.
  - `{:error, :sin_cupo}` si el albergue está lleno.
  - `{:error, :ya_esta_en_albergue}` si la persona ya estaba registrada.
  - `{:error, :no_encontrado}` si el albergue no existe.
  """
  def ingresar_persona(codigo, documento) do
    GenServer.call(__MODULE__, {:ingresar_persona, codigo, documento})
  end

  @doc """
  Registra la salida de una persona de un albergue.

  Si la persona está registrada, decrementa la ocupación y cambia su estado
  a `"reportada"`.

  ## Retorna
  - `{:ok, albergue_actualizado}` si la salida es exitosa.
  - `{:error, :no_esta_en_albergue}` si la persona no estaba en el albergue.
  - `{:error, :no_encontrado}` si el albergue no existe.
  """
  def egresar_persona(codigo, documento) do
    GenServer.call(__MODULE__, {:egresar_persona, codigo, documento})
  end

  @doc """
  Elimina un albergue del sistema.

  Solo permite eliminarlo si no tiene personas alojadas.

  ## Retorna
  - `:ok` si se elimina correctamente.
  - `{:error, :albergue_ocupado}` si tiene ocupantes.
  - `{:error, :no_encontrado}` si el albergue no existe.
  """
  def eliminar(codigo) do
    GenServer.call(__MODULE__, {:eliminar, codigo})
  end

  @doc """
  Asocia un recurso al albergue (lo agrega a su lista de recursos).

  ## Retorna
  - `{:ok, albergue_actualizado}` si se asocia correctamente.
  - `{:error, :ya_asociado}` si el recurso ya estaba asociado.
  - `{:error, :no_encontrado}` si el albergue no existe.
  """
  def asociar_recurso(codigo_albergue, codigo_recurso) do
    GenServer.call(__MODULE__, {:asociar_recurso, codigo_albergue, codigo_recurso})
  end

  @doc """
  Asocia una necesidad al albergue (la agrega a su lista de necesidades).

  ## Retorna
  - `{:ok, albergue_actualizado}` si se asocia correctamente.
  - `{:error, :ya_asociado}` si la necesidad ya estaba asociada.
  - `{:error, :no_encontrado}` si el albergue no existe.
  """
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
        case Emergencia.Personas.buscar_persona(documento) do
          {:error, :no_encontrada} ->
            {:reply, {:error, :persona_no_registrada}, albergues}

          {:ok, _persona} ->
            case Albergue.ingresar(albergue, documento) do
              {:ok, actualizado} ->
                nuevos_albergues = Map.put(albergues, codigo, actualizado)
                Emergencia.Persistencia.guardar_albergues(nuevos_albergues)

                Emergencia.Personas.cambiar_estado(documento, "en_albergue")

                {:reply, {:ok, actualizado}, nuevos_albergues}

              {:error, motivo} ->
                {:reply, {:error, motivo}, albergues}
            end
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

            Emergencia.Personas.cambiar_estado(documento, "reportada")

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
