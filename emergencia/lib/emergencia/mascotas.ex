defmodule Emergencia.Mascotas do
  use GenServer
  alias Emergencia.Mascotas.Mascota

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar(%Mascota{} = mascota), do: GenServer.call(__MODULE__, {:registrar, mascota})

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
      # Validación del tipo de reporte
      if mascota.tipo_reporte in Mascota.tipos() do
        nuevas_mascotas = Map.put(mascotas, mascota.id, mascota)
        Emergencia.Persistencia.guardar_mascotas(nuevas_mascotas)
        {:reply, {:ok, mascota}, nuevas_mascotas}
      else
        {:reply, {:error, :tipo_reporte_invalido}, mascotas}
      end
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

        # Si hay coincidencias, actualizamos el estado de AMBAS mascotas
        if length(coincidencias) > 0 do
          # Actualizamos la mascota consultada
          mascotas_actualizadas =
            if mascota.estado == "activa" do
              Map.put(mascotas, id, %{mascota | estado: "posible_coincidencia"})
            else
              mascotas
            end

          # Actualizamos cada mascota que coincidió
          mascotas_actualizadas =
            Enum.reduce(coincidencias, mascotas_actualizadas, fn {m_coincidente, _puntaje}, acc ->
              if m_coincidente.estado == "activa" do
                Map.put(acc, m_coincidente.id, %{m_coincidente | estado: "posible_coincidencia"})
              else
                acc
              end
            end)

          Emergencia.Persistencia.guardar_mascotas(mascotas_actualizadas)
          {:reply, {:ok, coincidencias}, mascotas_actualizadas}
        else
          {:reply, {:ok, coincidencias}, mascotas}
        end
    end
  end

  def handle_call({:resolver_coincidencia, id1, id2}, _from, mascotas) do
    with {:ok, m1} <- Map.fetch(mascotas, id1),
         {:ok, m2} <- Map.fetch(mascotas, id2) do
      cond do
        m1.estado == "resuelta" or m2.estado == "resuelta" ->
          {:reply, {:error, :ya_resuelta}, mascotas}

        true ->
          # Marcamos ambos como resueltos y los vinculamos
          m1_act = %{m1 | estado: "resuelta", reporte_vinculado: id2}
          m2_act = %{m2 | estado: "resuelta", reporte_vinculado: id1}

          nuevas_mascotas =
            mascotas
            |> Map.put(id1, m1_act)
            |> Map.put(id2, m2_act)

          Emergencia.Persistencia.guardar_mascotas(nuevas_mascotas)

          {:reply, {:ok, m1_act, m2_act}, nuevas_mascotas}
      end
    else
      _ -> {:reply, {:error, :no_encontradas}, mascotas}
    end
  end
end
