defmodule Emergencia.Personas do
  @moduledoc """
  GenServer que administra el estado de las personas afectadas y los mensajes
  familiares.

  A diferencia de otros módulos, este GenServer maneja un estado doble:
  - Un mapa de personas indexado por documento.
  - Un mapa de mensajes indexado por ID.

  Sus responsabilidades principales son:
  - Registrar personas y cambiar su estado, manteniendo un historial de cambios.
  - Sincronizar el estado de la persona con el módulo de Albergues (al cambiar
    a `"reunificada"`, la persona sale automáticamente del albergue).
  - Enviar mensajes dirigidos a una persona y marcarlos como leídos.
  """

  use GenServer
  alias Emergencia.Personas.{Persona, Mensaje}

  # ---------- API Pública ----------

  @doc """
  Inicia el GenServer y registra el proceso con el nombre `Emergencia.Personas`.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{personas: %{}, mensajes: %{}}, name: __MODULE__)
  end

  @doc """
  Registra una nueva persona afectada.

  El estado inicial siempre es `"reportada"` y se le asigna la fecha actual al
  primer registro del historial.

  ## Retorna
  - `{:ok, persona}` si se registra correctamente.
  - `{:error, :persona_ya_existe}` si ya hay una persona con ese documento.
  """
  def registrar_persona(%Persona{} = p), do: GenServer.call(__MODULE__, {:registrar_persona, p})

  @doc """
  Busca una persona por su documento.

  ## Retorna
  - `{:ok, persona}` si existe.
  - `{:error, :no_encontrada}` en caso contrario.
  """
  def buscar_persona(documento), do: GenServer.call(__MODULE__, {:buscar_persona, documento})

  @doc """
  Devuelve la lista de todas las personas registradas.
  """
  def listar_personas, do: GenServer.call(__MODULE__, :listar_personas)

  @doc """
  Cambia el estado de una persona y agrega una entrada al historial.

  Si el nuevo estado es `"reunificada"`, busca a la persona en todos los
  albergues y registra su salida automáticamente.

  ## Retorna
  - `{:ok, persona_actualizada}` si el cambio es exitoso.
  - `{:error, :no_encontrada}` si la persona no existe.
  - `{:error, :estado_invalido}` si el estado no es válido.
  """
  def cambiar_estado(documento, nuevo_estado),
    do: GenServer.call(__MODULE__, {:cambiar_estado, documento, nuevo_estado})

  @doc """
  Envía un mensaje a una persona (destinatario).

  Asigna automáticamente la fecha actual al mensaje.

  ## Retorna
  - `{:ok, mensaje}` si se envía correctamente.
  """
  def enviar_mensaje(%Mensaje{} = m), do: GenServer.call(__MODULE__, {:enviar_mensaje, m})

  @doc """
  Devuelve la lista de mensajes dirigidos a una persona, ordenados del más
  reciente al más antiguo.
  """
  def listar_mensajes(documento), do: GenServer.call(__MODULE__, {:listar_mensajes, documento})

  @doc """
  Marca un mensaje como leído.

  ## Retorna
  - `{:ok, mensaje_actualizado}` si se marca correctamente.
  - `{:error, :no_encontrado}` si el mensaje no existe.
  """
  def marcar_mensaje_leido(id) do
    GenServer.call(__MODULE__, {:marcar_mensaje_leido, id})
  end

  # ---------- Callbacks ----------

  @impl true
  def init(_opts) do
    personas =
      case Emergencia.Persistencia.leer_personas() do
        {:ok, p} -> p
        _ -> %{}
      end

    mensajes =
      case Emergencia.Persistencia.leer_mensajes() do
        {:ok, m} -> m
        _ -> %{}
      end

    {:ok, %{personas: personas, mensajes: mensajes}}
  end

  @impl true
  def handle_call({:registrar_persona, persona}, _from, state) do
    if Map.has_key?(state.personas, persona.documento) do
      {:reply, {:error, :persona_ya_existe}, state}
    else
      nueva_persona = %{
        persona
        | estado: "reportada",
          historial_estados: [
            %{estado: "reportada", fecha: DateTime.utc_now() |> DateTime.to_string()}
          ]
      }

      nuevas_personas = Map.put(state.personas, persona.documento, nueva_persona)
      Emergencia.Persistencia.guardar_personas(nuevas_personas)
      {:reply, {:ok, nueva_persona}, %{state | personas: nuevas_personas}}
    end
  end

  def handle_call({:buscar_persona, documento}, _from, state) do
    case Map.get(state.personas, documento) do
      nil -> {:reply, {:error, :no_encontrada}, state}
      p -> {:reply, {:ok, p}, state}
    end
  end

  def handle_call(:listar_personas, _from, state) do
    {:reply, Map.values(state.personas), state}
  end

  def handle_call({:cambiar_estado, documento, nuevo_estado}, _from, state) do
    case Map.get(state.personas, documento) do
      nil ->
        {:reply, {:error, :no_encontrada}, state}

      persona ->
        if Persona.estado_valido?(nuevo_estado) do
          nuevo_historial = [
            %{estado: nuevo_estado, fecha: DateTime.utc_now() |> DateTime.to_string()}
            | persona.historial_estados
          ]

          persona_actualizada = %{
            persona
            | estado: nuevo_estado,
              historial_estados: nuevo_historial
          }

          nuevas_personas = Map.put(state.personas, documento, persona_actualizada)
          Emergencia.Persistencia.guardar_personas(nuevas_personas)

          # Si se reunifica, lo sacamos del albergue
          if nuevo_estado == "reunificada" do
            Enum.each(Emergencia.Albergues.listar(), fn albergue ->
              if documento in albergue.personas do
                Emergencia.Albergues.egresar_persona(albergue.codigo, documento)
              end
            end)
          end

          {:reply, {:ok, persona_actualizada}, %{state | personas: nuevas_personas}}
        else
          {:reply, {:error, :estado_invalido}, state}
        end
    end
  end

  def handle_call({:enviar_mensaje, mensaje}, _from, state) do
    nuevo_mensaje = %{mensaje | fecha: DateTime.utc_now() |> DateTime.to_string()}
    nuevos_mensajes = Map.put(state.mensajes, mensaje.id, nuevo_mensaje)
    {:reply, {:ok, nuevo_mensaje}, %{state | mensajes: nuevos_mensajes}}
  end

  def handle_call({:listar_mensajes, documento}, _from, state) do
    mensajes =
      state.mensajes
      |> Map.values()
      |> Enum.filter(&(&1.documento_destino == documento))
      |> Enum.sort_by(& &1.fecha, :desc)

    {:reply, mensajes, state}
  end

  def handle_call({:marcar_mensaje_leido, id}, _from, state) do
    case Map.get(state.mensajes, id) do
      nil ->
        {:reply, {:error, :no_encontrado}, state}

      mensaje ->
        actualizado = %{mensaje | leido: true}
        nuevos_mensajes = Map.put(state.mensajes, id, actualizado)
        Emergencia.Persistencia.guardar_mensajes(nuevos_mensajes)
        {:reply, {:ok, actualizado}, %{state | mensajes: nuevos_mensajes}}
    end
  end
end
