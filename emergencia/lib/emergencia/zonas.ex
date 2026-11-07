defmodule Emergencia.Zonas do
  @moduledoc """
  GenServer que mantiene el estado de las zonas afectadas.
  """

  use GenServer
  alias Emergencia.Zonas.Zona

  # ---------- API pública ----------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registra una zona nueva. Calcula automáticamente el total de personas afectadas
  usando la función recursiva de la Zona.
  """
  def registrar(%Zona{} = zona) do
    GenServer.call(__MODULE__, {:registrar, zona})
  end

  @doc """
  Busca una zona por su código.
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
  Borra una zona registrada.
  """
  def eliminar(codigo) do
    GenServer.call(__MODULE__, {:eliminar, codigo})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(_opts) do
    # Usamos Emergencia.Persistencia directo
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
      zona_actualizada = %{zona | personas_afectadas: Zona.calcular_total_personas(zona)}
      nuevas_zonas = Map.put(zonas, zona.codigo, zona_actualizada)

      # Usamos Emergencia.Persistencia directo
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
