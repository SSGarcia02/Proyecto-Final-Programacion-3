defmodule Emergencia.Zonas do
  @moduledoc """
  GenServer que administra el estado de las zonas afectadas por la emergencia.

  Este módulo mantiene en memoria un mapa de zonas indexado por código. Al
  registrar una nueva zona, delega el cálculo del total de personas afectadas a
  la función recursiva `Zona.calcular_total_personas/1`, que recorre la
  jerarquía Zona → Sectores → Puntos.

  La persistencia se realiza en `data/zonas.csv`. Para evitar conflictos con las
  comas del JSON (que guarda los sectores anidados), se utiliza el separador `|`.
  """

  use GenServer
  alias Emergencia.Zonas.Zona

  # ---------- API pública ----------

  @doc """
  Inicia el GenServer y registra el proceso con el nombre `Emergencia.Zonas`.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registra una zona nueva en el sistema.

  Antes de guardarla, calcula el total de personas afectadas usando la función
  recursiva `Zona.calcular_total_personas/1`. Si el código no existe, la
  persiste en el CSV.

  ## Retorna
  - `{:ok, zona_actualizada}` si se registra correctamente.
  - `{:error, :zona_ya_existe}` si ya hay una zona con ese código.
  """
  def registrar(%Zona{} = zona) do
    GenServer.call(__MODULE__, {:registrar, zona})
  end

  @doc """
  Busca una zona por su código.

  ## Retorna
  - `{:ok, zona}` si existe.
  - `{:error, :no_encontrada}` en caso contrario.
  """
  def buscar(codigo) do
    GenServer.call(__MODULE__, {:buscar, codigo})
  end

  @doc """
  Devuelve la lista de todas las zonas registradas.
  """
  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  @doc """
  Elimina una zona del sistema.

  ## Retorna
  - `:ok` si se elimina correctamente.
  - `{:error, :no_encontrada}` si la zona no existe.
  """
  def eliminar(codigo) do
    GenServer.call(__MODULE__, {:eliminar, codigo})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(_opts) do
    case Emergencia.Persistencia.leer_zonas() do
      {:ok, zonas} -> {:ok, zonas}
      {:error, _} -> {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:registrar, zona}, _from, zonas) do
    if Map.has_key?(zonas, zona.codigo) do
      {:reply, {:error, :zona_ya_existe}, zonas}
    else
      # Calculamos el total recursivamente con los puntos (que estarán en 0)
      # y guardamos la zona. La recursividad se sigue usando para demostrar el concepto.
      zona_actualizada = %{zona | personas_afectadas: Zona.calcular_total_personas(zona)}
      nuevas_zonas = Map.put(zonas, zona.codigo, zona_actualizada)

      Emergencia.Persistencia.guardar_zonas(nuevas_zonas)
      {:reply, {:ok, zona_actualizada}, nuevas_zonas}
    end
  end

  def handle_call({:buscar, codigo}, _from, zonas) do
    case Map.get(zonas, codigo) do
      nil -> {:reply, {:error, :no_encontrada}, zonas}
      zona -> {:reply, {:ok, zona}, zonas}
    end
  end

  def handle_call(:listar, _from, zonas) do
    {:reply, Map.values(zonas), zonas}
  end

  @impl true
  def handle_call({:eliminar, codigo}, _from, zonas) do
    if Map.has_key?(zonas, codigo) do
      nuevas_zonas = Map.delete(zonas, codigo)
      Emergencia.Persistencia.guardar_zonas(nuevas_zonas)
      {:reply, :ok, nuevas_zonas}
    else
      {:reply, {:error, :no_encontrada}, zonas}
    end
  end
end
