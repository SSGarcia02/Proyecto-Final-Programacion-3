defmodule Emergencia.Usuarios do
  @moduledoc """
  GenServer que mantiene en memoria el estado de los usuarios registrados
  y lo persiste en `data/usuarios.csv`.

  El estado interno es un mapa `%{username => %Usuario{}}`.

  Todas las operaciones que modifican el estado se guardan en disco
  después de aplicarse, usando `Emergencia.Persistencia.guardar_usuarios/1`.
  """

  use GenServer

  alias Emergencia.Persistencia
  alias Emergencia.Usuarios.Usuario

  # ---------- API pública ----------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registra un usuario nuevo.
  Devuelve `{:ok, usuario}` o `{:error, motivo}`.
  """
  def registrar(username, password, nombre_completo, tipo, zona) do
    GenServer.call(__MODULE__, {:registrar, username, password, nombre_completo, tipo, zona})
  end

  @doc """
  Conecta a un usuario.

  - Si no existe, lo registra automáticamente con los datos recibidos.
  - Si existe, valida que la contraseña coincida.

  Devuelve `{:ok, usuario}` o `{:error, motivo}`.
  """
  def conectar(username, password, tipo \\ :ciudadano, zona \\ "sin_zona", nombre_completo \\ nil) do
    GenServer.call(__MODULE__, {:conectar, username, password, tipo, zona, nombre_completo})
  end

  @doc """
  Marca al usuario como desconectado.
  """
  def desconectar(username) do
    GenServer.cast(__MODULE__, {:desconectar, username})
  end

  @doc """
  Busca un usuario por su username.
  Devuelve `{:ok, usuario}` o `{:error, :no_encontrado}`.
  """
  def buscar(username) do
    GenServer.call(__MODULE__, {:buscar, username})
  end

  @doc """
  Devuelve la lista de todos los usuarios registrados.
  """
  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  @doc """
  Registra una actividad asociada a un usuario.
  Por ahora se guarda en el log del servidor (IO.inspect).
  """
  def registrar_actividad(username, actividad) do
    GenServer.cast(__MODULE__, {:actividad, username, actividad})
  end

  # ---------- Callbacks del GenServer ----------

  @impl true
  def init(_opts) do
    case Persistencia.leer_usuarios() do
      {:ok, usuarios} ->
        {:ok, usuarios}

      {:error, razon} ->
        IO.puts(:standard_error, "No se pudieron cargar los usuarios: #{inspect(razon)}")
        {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:registrar, username, password, nombre_completo, tipo, zona}, _from, usuarios) do
    case do_registrar(usuarios, username, password, nombre_completo, tipo, zona) do
      {:ok, usuario, nuevos_usuarios} ->
        persistir(nuevos_usuarios)
        {:reply, {:ok, usuario}, nuevos_usuarios}

      {:error, motivo} ->
        {:reply, {:error, motivo}, usuarios}
    end
  end

  def handle_call({:conectar, username, password, tipo, zona, nombre_completo}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil ->
        # No existe: registro automático (regla del enunciado)
        case do_registrar(usuarios, username, password, nombre_completo, tipo, zona) do
          {:ok, usuario, nuevos_usuarios} ->
            persistir(nuevos_usuarios)
            {:reply, {:ok, usuario}, nuevos_usuarios}

          {:error, motivo} ->
            {:reply, {:error, motivo}, usuarios}
        end

      %Usuario{password: ^password} = usuario ->
        actualizado = %{usuario | conectado: true}
        nuevos_usuarios = Map.put(usuarios, username, actualizado)
        persistir(nuevos_usuarios)
        {:reply, {:ok, actualizado}, nuevos_usuarios}

      _ ->
        {:reply, {:error, :password_incorrecta}, usuarios}
    end
  end

  def handle_call({:buscar, username}, _from, usuarios) do
    case Map.get(usuarios, username) do
      nil -> {:reply, {:error, :no_encontrado}, usuarios}
      usuario -> {:reply, {:ok, usuario}, usuarios}
    end
  end

  def handle_call(:listar, _from, usuarios) do
    {:reply, Map.values(usuarios), usuarios}
  end

  @impl true
  def handle_cast({:desconectar, username}, usuarios) do
    nuevos_usuarios =
      case Map.get(usuarios, username) do
        nil ->
          usuarios

        usuario ->
          Map.put(usuarios, username, %{usuario | conectado: false})
      end

    persistir(nuevos_usuarios)
    {:noreply, nuevos_usuarios}
  end

  def handle_cast({:actividad, username, actividad}, usuarios) do
    IO.inspect({username, actividad}, label: "[actividad]")
    {:noreply, usuarios}
  end

  # ---------- Helpers privados ----------

  # Intenta construir y agregar un usuario.
  # Devuelve {:ok, usuario, nuevos_usuarios} o {:error, motivo}.
  defp do_registrar(usuarios, username, password, nombre_completo, tipo, zona) do
    cond do
      Map.has_key?(usuarios, username) ->
        {:error, :usuario_ya_existe}

      not Usuario.tipo_valido?(tipo) ->
        {:error, :tipo_invalido}

      not is_binary(password) or String.trim(password) == "" ->
        {:error, :password_vacio}

      not is_binary(username) or String.trim(username) == "" ->
        {:error, :username_vacio}

      not is_binary(zona) or String.trim(zona) == "" ->
        {:error, :zona_vacia}

      true ->
        usuario = %Usuario{
          username: username,
          password: password,
          nombre_completo: nombre_completo || username,
          tipo: tipo,
          zona: zona,
          conectado: true
        }

        if Persistencia.usuario_valido_para_csv?(usuario) do
          {:ok, usuario, Map.put(usuarios, username, usuario)}
        else
          # Red de seguridad: campos con comas o caracteres peligrosos para CSV
          {:error, :campo_invalido}
        end
    end
  end

  # Guarda el mapa completo en disco.
  # Si falla, no interrumpe la operación (el estado en memoria sigue válido);
  # solo lo deja en el log de errores.
  defp persistir(usuarios) do
    case Persistencia.guardar_usuarios(usuarios) do
      {:ok, _escritos, []} ->
        :ok

      {:ok, _escritos, omitidos} ->
        IO.puts(:standard_error, "Usuarios omitidos al guardar: #{inspect(omitidos)}")

      {:error, razon} ->
        IO.puts(:standard_error, "Error al persistir usuarios: #{inspect(razon)}")
    end
  end
end
