defmodule Emergencia.Personas do
  use GenServer
  alias Emergencia.Personas.{Persona, Mensaje}

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{personas: %{}, mensajes: %{}}, name: __MODULE__)
  end

  # API Personas
  def registrar_persona(%Persona{} = p), do: GenServer.call(__MODULE__, {:registrar_persona, p})
  def buscar_persona(documento), do: GenServer.call(__MODULE__, {:buscar_persona, documento})
  def listar_personas, do: GenServer.call(__MODULE__, :listar_personas)

  def cambiar_estado(documento, nuevo_estado),
    do: GenServer.call(__MODULE__, {:cambiar_estado, documento, nuevo_estado})

  # API Mensajes
  def enviar_mensaje(%Mensaje{} = m), do: GenServer.call(__MODULE__, {:enviar_mensaje, m})
  def listar_mensajes(documento), do: GenServer.call(__MODULE__, {:listar_mensajes, documento})

  def marcar_mensaje_leido(id) do
    GenServer.call(__MODULE__, {:marcar_mensaje_leido, id})
  end

  # Callbacks
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
      # <-- NUEVO
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
          # Agregamos el cambio al historial
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
        {:reply, {:ok, actualizado}, %{state | mensajes: nuevos_mensajes}}
    end
  end
end
