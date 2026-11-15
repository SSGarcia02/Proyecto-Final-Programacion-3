defmodule Emergencia.Mascotas do
  @moduledoc """
  GenServer que administra el estado de los reportes de mascotas perdidas y
  encontradas durante la emergencia.

  Este módulo es el encargado de mantener en memoria el mapa de reportes, de
  ejecutar el algoritmo de búsqueda de coincidencias y de persistir los cambios
  en el archivo `data/mascotas.csv`.

  Las responsabilidades principales de este GenServer son:
  - Registrar nuevos reportes (validando que el tipo sea "perdida" o "encontrada").
  - Buscar posibles coincidencias entre reportes activos aplicando el algoritmo
    de similitud del struct `Mascota`.
  - Actualizar el estado de las mascotas a `"posible_coincidencia"` cuando se
    detecta un match.
  - Resolver una coincidencia confirmada, cerrando ambos reportes y vinculándolos.
  """

  use GenServer
  alias Emergencia.Mascotas.Mascota

  # ---------- API Pública ----------

  @doc """
  Inicia el GenServer y registra el proceso con el nombre `Emergencia.Mascotas`.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registra un nuevo reporte de mascota (perdida o encontrada).

  Valida que el ID no esté duplicado y que el tipo de reporte sea válido
  (`"perdida"` o `"encontrada"`).

  ## Retorna
  - `{:ok, mascota}` si se registra correctamente.
  - `{:error, :id_duplicado}` si ya existe un reporte con ese ID.
  - `{:error, :tipo_reporte_invalido}` si el tipo no es válido.
  """
  def registrar(%Mascota{} = mascota), do: GenServer.call(__MODULE__, {:registrar, mascota})

  @doc """
  Devuelve la lista de todos los reportes registrados.
  """
  def listar, do: GenServer.call(__MODULE__, :listar)

  @doc """
  Busca un reporte por su ID.

  ## Retorna
  - `{:ok, mascota}` si existe.
  - `{:error, :no_encontrada}` en caso contrario.
  """
  def buscar(id), do: GenServer.call(__MODULE__, {:buscar, id})

  @doc """
  Busca posibles coincidencias para un reporte dado.

  Recorre todos los reportes activos, calcula el puntaje de similitud usando
  `Mascota.calcular_coincidencia/2` y filtra aquellos con puntaje mayor o igual
  a 50. Si encuentra coincidencias, actualiza el estado de la mascota consultada
  y de las coincidentes a `"posible_coincidencia"` y persiste los cambios.

  ## Retorna
  - `{:ok, lista_coincidencias}` donde cada elemento es `{mascota, puntaje}`.
  - `{:error, :no_encontrada}` si el ID no existe.
  """
  def buscar_coincidencias(id) do
    GenServer.call(__MODULE__, {:buscar_coincidencias, id})
  end

  @doc """
  Resuelve una coincidencia confirmada entre dos reportes.

  Marca ambos reportes como `"resuelta"`, los vincula mutuamente con el campo
  `reporte_vinculado` y persiste los cambios.

  ## Retorna
  - `{:ok, m1_actualizada, m2_actualizada}` si se resuelve correctamente.
  - `{:error, :ya_resuelta}` si alguno de los reportes ya estaba resuelto.
  - `{:error, :no_encontradas}` si alguno de los IDs no existe.
  """
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
