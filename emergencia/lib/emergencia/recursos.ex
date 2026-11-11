defmodule Emergencia.Recursos do
  @moduledoc """
  GenServer que administra el inventario de recursos.
  """
  use GenServer
  alias Emergencia.Recursos.Recurso

  # ---------- API Pública ----------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar(%Recurso{} = recurso) do
    GenServer.call(__MODULE__, {:registrar, recurso})
  end

  def buscar(codigo) do
    GenServer.call(__MODULE__, {:buscar, codigo})
  end

  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  def ingresar(codigo, cantidad) do
    GenServer.call(__MODULE__, {:ingresar, codigo, cantidad})
  end

  def egresar(codigo, cantidad) do
    GenServer.call(__MODULE__, {:egresar, codigo, cantidad})
  end

  def eliminar(codigo) do
    GenServer.call(__MODULE__, {:eliminar, codigo})
  end

  def actualizar(%Recurso{} = recurso) do
    GenServer.call(__MODULE__, {:actualizar, recurso})
  end

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
      # <-- NUEVO
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

    # Lo volvemos a registrar con los datos nuevos (esto recalcula y guarda en CSV)
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
