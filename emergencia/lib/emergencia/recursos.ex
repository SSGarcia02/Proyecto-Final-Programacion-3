defmodule Emergencia.Recursos do
  @moduledoc """
  GenServer que administra el inventario de recursos (agua, alimentos, medicamentos,
  etc.) disponibles en los centros de acopio.

  Este módulo mantiene en memoria un mapa de recursos indexado por código, y
  expone una API pública que las LiveViews utilizan para registrar entradas,
  salidas y transferencias de inventario.

  Al ser un GenServer, las peticiones se procesan de forma serializada (una a la
  vez). Esto garantiza que si múltiples usuarios intentan egresar el mismo
  recurso simultáneamente, el inventario nunca se vuelva negativo: la primera
  petición se procesa con el stock real, y la segunda recibe un error
  `{:error, :sin_existencias}` si ya no queda suficiente.
  """

  use GenServer
  alias Emergencia.Recursos.Recurso

  # ---------- API Pública ----------

  @doc """
  Inicia el GenServer y registra el proceso con el nombre `Emergencia.Recursos`.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registra un recurso nuevo en el inventario.

  ## Retorna
  - `{:ok, recurso}` si se registra correctamente.
  - `{:error, :recurso_ya_existe}` si ya hay uno con ese código.
  """
  def registrar(%Recurso{} = recurso) do
    GenServer.call(__MODULE__, {:registrar, recurso})
  end

  @doc """
  Busca un recurso por su código.

  ## Retorna
  - `{:ok, recurso}` si existe.
  - `{:error, :no_encontrado}` en caso contrario.
  """
  def buscar(codigo) do
    GenServer.call(__MODULE__, {:buscar, codigo})
  end

  @doc """
  Devuelve la lista de todos los recursos en inventario.
  """
  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  @doc """
  Registra una entrada de inventario (suma cantidad al stock del recurso).

  ## Retorna
  - `{:ok, recurso_actualizado}` si la cantidad es válida.
  - `{:error, :cantidad_invalida}` si la cantidad no es un entero positivo.
  - `{:error, :no_encontrado}` si el recurso no existe.
  """
  def ingresar(codigo, cantidad) do
    GenServer.call(__MODULE__, {:ingresar, codigo, cantidad})
  end

  @doc """
  Registra una salida de inventario (resta cantidad al stock del recurso).

  Valida que haya suficientes existencias antes de descontar.

  ## Retorna
  - `{:ok, recurso_actualizado}` si hay existencias suficientes.
  - `{:error, :sin_existencias}` si la cantidad solicitada supera el stock.
  - `{:error, :cantidad_invalida}` si la cantidad no es un entero positivo.
  - `{:error, :no_encontrado}` si el recurso no existe.
  """
  def egresar(codigo, cantidad) do
    GenServer.call(__MODULE__, {:egresar, codigo, cantidad})
  end

  @doc """
  Elimina un recurso del inventario.

  ## Retorna
  - `:ok` si se elimina correctamente.
  - `{:error, :no_encontrado}` si el recurso no existe.
  """
  def eliminar(codigo) do
    GenServer.call(__MODULE__, {:eliminar, codigo})
  end

  @doc """
  Actualiza los datos de un recurso existente (nombre, categoría, unidad, etc.).

  ## Retorna
  - `{:ok, recurso}` si se actualiza correctamente.
  """
  def actualizar(%Recurso{} = recurso) do
    GenServer.call(__MODULE__, {:actualizar, recurso})
  end

  @doc """
  Transfiere una cantidad de un recurso origen a un recurso destino.

  Ambos recursos deben existir en el inventario y pertenecer a la misma categoría.

  ## Retorna
  - `{:ok, origen_actualizado, destino_actualizado}` si la transferencia es exitosa.
  - `{:error, :mismo_recurso}` si el origen y el destino tienen el mismo código.
  - `{:error, :categoria_incompatible}` si las categorías no coinciden.
  - `{:error, :sin_existencias}` si el origen no tiene suficientes unidades.
  - `{:error, :recurso_no_encontrado}` si alguno de los códigos no existe.
  - `{:error, :cantidad_invalida}` si la cantidad no es válida.
  """
  def transferir(codigo_origen, codigo_destino, cantidad) do
    GenServer.call(__MODULE__, {:transferir, codigo_origen, codigo_destino, cantidad})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(_opts) do
    case Emergencia.Persistencia.leer_recursos() do
      {:ok, recursos} -> {:ok, recursos}
      {:error, _} -> {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:registrar, recurso}, _from, recursos) do
    if Map.has_key?(recursos, recurso.codigo) do
      {:reply, {:error, :recurso_ya_existe}, recursos}
    else
      nuevos_recursos = Map.put(recursos, recurso.codigo, recurso)
      Emergencia.Persistencia.guardar_recursos(nuevos_recursos)
      {:reply, {:ok, recurso}, nuevos_recursos}
    end
  end

  def handle_call({:buscar, codigo}, _from, recursos) do
    case Map.get(recursos, codigo) do
      nil -> {:reply, {:error, :no_encontrado}, recursos}
      recurso -> {:reply, {:ok, recurso}, recursos}
    end
  end

  def handle_call(:listar, _from, recursos) do
    {:reply, Map.values(recursos), recursos}
  end

  def handle_call({:ingresar, codigo, cantidad}, _from, recursos) do
    case Map.get(recursos, codigo) do
      nil ->
        {:reply, {:error, :no_encontrado}, recursos}

      recurso ->
        case Recurso.ingresar(recurso, cantidad) do
          {:ok, actualizado} ->
            nuevos_recursos = Map.put(recursos, codigo, actualizado)
            Emergencia.Persistencia.guardar_recursos(nuevos_recursos)
            {:reply, {:ok, actualizado}, nuevos_recursos}

          {:error, motivo} ->
            {:reply, {:error, motivo}, recursos}
        end
    end
  end

  def handle_call({:egresar, codigo, cantidad}, _from, recursos) do
    case Map.get(recursos, codigo) do
      nil ->
        {:reply, {:error, :no_encontrado}, recursos}

      recurso ->
        case Recurso.egresar(recurso, cantidad) do
          {:ok, actualizado} ->
            nuevos_recursos = Map.put(recursos, codigo, actualizado)
            Emergencia.Persistencia.guardar_recursos(nuevos_recursos)
            {:reply, {:ok, actualizado}, nuevos_recursos}

          {:error, motivo} ->
            {:reply, {:error, motivo}, recursos}
        end
    end
  end

  @impl true
  def handle_call({:eliminar, codigo}, _from, recursos) do
    if Map.has_key?(recursos, codigo) do
      nuevos_recursos = Map.delete(recursos, codigo)
      Emergencia.Persistencia.guardar_recursos(nuevos_recursos)
      {:reply, :ok, nuevos_recursos}
    else
      {:reply, {:error, :no_encontrado}, recursos}
    end
  end

  def handle_call({:actualizar, recurso}, _from, recursos) do
    # Si el código cambió, eliminamos el viejo
    recursos_sin_viejo = Map.delete(recursos, recurso.codigo)

    # Lo volvemos a registrar con los datos nuevos
    nuevos_recursos = Map.put(recursos_sin_viejo, recurso.codigo, recurso)
    Emergencia.Persistencia.guardar_recursos(nuevos_recursos)
    {:reply, {:ok, recurso}, nuevos_recursos}
  end

  def handle_call({:transferir, codigo_origen, codigo_destino, cantidad}, _from, recursos) do
    with {:ok, origen} <- Map.fetch(recursos, codigo_origen),
         {:ok, destino} <- Map.fetch(recursos, codigo_destino),
         {:ok, origen_act, destino_act} <- Recurso.transferir(origen, destino, cantidad) do
      nuevos_recursos =
        recursos
        |> Map.put(codigo_origen, origen_act)
        |> Map.put(codigo_destino, destino_act)

      Emergencia.Persistencia.guardar_recursos(nuevos_recursos)
      {:reply, {:ok, origen_act, destino_act}, nuevos_recursos}
    else
      :error -> {:reply, {:error, :recurso_no_encontrado}, recursos}
      {:error, motivo} -> {:reply, {:error, motivo}, recursos}
    end
  end
end
