defmodule Emergencia.Mascotas do
  use GenServer
  alias Emergencia.Mascotas.Mascota

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar(%Mascota{} = m), do: GenServer.call(__MODULE__, {:registrar, m})
  def listar, do: GenServer.call(__MODULE__, :listar)
  def buscar(id), do: GenServer.call(__MODULE__, {:buscar, id})

  def buscar_coincidencias(id) do
    GenServer.call(__MODULE__, {:buscar_coincidencias, id})
  end

  def resolver_coincidencia(id1, id2) do
    GenServer.call(__MODULE__, {:resolver_coincidencia, id1, id2})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(_opts) do
    case Emergencia.Persistencia.leer_mascotas() do
      {:ok, mascotas} -> {:ok, mascotas}
      {:error, _} -> {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:registrar, mascota}, _from, mascotas) do
    if Map.has_key?(mascotas, mascota.id) do
      {:reply, {:error, :id_duplicado}, mascotas}
    else
      # Al registrar, buscamos si ya hay una posible coincidencia inmediata
      nuevas_mascotas = Map.put(mascotas, mascota.id, mascota)
      Emergencia.Persistencia.guardar_mascotas(nuevas_mascotas)
      {:reply, {:ok, mascota}, nuevas_mascotas}
    end
  end

  def handle_call(:listar, _from, mascotas) do
    {:reply, Map.values(mascotas), mascotas}
  end

  def handle_call({:buscar, id}, _from, mascotas) do
    case Map.get(mascotas, id) do
      nil -> {:reply, {:error, :no_encontrada}, mascotas}
      m -> {:reply, {:ok, m}, mascotas}
    end
  end

  def handle_call({:buscar_coincidencias, id}, _from, mascotas) do
    case Map.get(mascotas, id) do
      nil ->
        {:reply, {:error, :no_encontrada}, mascotas}

      mascota ->
        # Buscamos en todos los reportes activos
        coincidencias =
          mascotas
          |> Map.values()
          |> Enum.filter(&(&1.id != id and &1.estado == "activa"))
          |> Enum.map(fn m -> {m, Mascota.calcular_coincidencia(mascota, m)} end)
          |> Enum.filter(fn {_m, puntaje} -> puntaje >= 50 end)
          |> Enum.sort_by(fn {_m, puntaje} -> puntaje end, :desc)

        # Si hay coincidencias y la mascota estaba activa, la pasamos a "posible_coincidencia"
        if length(coincidencias) > 0 and mascota.estado == "activa" do
          mascota_actualizada = %{mascota | estado: "posible_coincidencia"}
          nuevas_mascotas = Map.put(mascotas, id, mascota_actualizada)
          Emergencia.Persistencia.guardar_mascotas(nuevas_mascotas)
          {:reply, {:ok, coincidencias}, nuevas_mascotas}
        else
          {:reply, {:ok, coincidencias}, mascotas}
        end
    end
  end

  def handle_call({:resolver_coincidencia, id1, id2}, _from, mascotas) do
    with {:ok, m1} <- Map.fetch(mascotas, id1),
         {:ok, m2} <- Map.fetch(mascotas, id2) do
      # Marcamos ambos como resueltos y los vinculamos
      m1_act = %{m1 | estado: "resuelta", reporte_vinculado: id2}
      m2_act = %{m2 | estado: "resuelta", reporte_vinculado: id1}

      nuevas_mascotas =
        mascotas
        |> Map.put(id1, m1_act)
        |> Map.put(id2, m2_act)

      Emergencia.Persistencia.guardar_mascotas(nuevas_mascotas)

      {:reply, {:ok, m1_act, m2_act}, nuevas_mascotas}
    else
      _ -> {:reply, {:error, :no_encontradas}, mascotas}
    end
  end
end
