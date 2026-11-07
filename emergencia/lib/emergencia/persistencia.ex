defmodule Emergencia.Persistencia do
  @moduledoc """
  Módulo centralizado para leer y escribir archivos CSV en `data/`.

  Reglas:
  - Un registro por línea, campos separados por coma.
  - Los campos de texto NO pueden contener comas (para mantenerlo simple).
  - La primera línea es siempre encabezado.
  - Cada archivo tiene su propio conjunto de columnas.
  """

  @data_dir Path.join([__DIR__, "..", "..", "data"])

  # ---------- Rutas y verificación ----------

  @doc """
  Devuelve la ruta absoluta a un archivo dentro de `data/`.
  """
  def ruta(archivo) do
    Path.join(@data_dir, archivo)
  end

  @doc """
  Verifica que la carpeta data/ exista.
  """
  def verificar_carpeta do
    if File.dir?(@data_dir) do
      {:ok, @data_dir}
    else
      {:error, :carpeta_no_encontrada}
    end
  end

  # ---------- Lectura genérica ----------

  @doc """
  Lee un CSV y devuelve sus filas de datos (sin el encabezado).

  Devuelve `{:ok, filas}` o `{:error, motivo}`.
  Cada fila es una lista de strings.
  Si el archivo no existe, devuelve `{:ok, []}` (no es error).
  """
  def leer_filas(nombre_archivo) do
    ruta_archivo = ruta(nombre_archivo)

    case File.read(ruta_archivo) do
      {:ok, contenido} ->
        filas =
          contenido
          |> String.split("\n", trim: true)
          # descarta encabezado
          |> Enum.drop(1)
          # cada línea -> lista de strings
          |> Enum.map(&String.split(&1, ","))

        {:ok, filas}

      {:error, :enoent} ->
        {:ok, []}

      {:error, razon} ->
        {:error, razon}
    end
  end

  # ---------- Escritura genérica ----------

  @doc """
  Escribe un CSV completo (encabezado + filas).
  Sobrescribe el archivo si ya existe.

  `encabezado` es una lista de strings.
  `filas` es una lista de listas de strings.

  Devuelve `:ok` o `{:error, motivo}`.
  """
  def escribir_filas(nombre_archivo, encabezado, filas) do
    contenido =
      [encabezado | filas]
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")
      |> Kernel.<>("\n")

    File.write(ruta(nombre_archivo), contenido)
  end

  # ---------- Utilidades de validación ----------

  @doc """
  Verifica que un campo de texto no contenga comas ni saltos de línea.
  Devuelve :ok o {:error, :campo_invalido}.
  """
  def campo_seguro?(valor) when is_binary(valor) do
    not String.contains?(valor, [",", "\n", "\r"])
  end

  def campo_seguro?(_), do: false

  # ---------- Conversión de Usuario <-> fila CSV ----------

  alias Emergencia.Usuarios.Usuario

  @encabezado_usuarios ["username", "password", "nombre_completo", "tipo", "zona", "conectado"]

  @doc """
  Devuelve el encabezado del CSV de usuarios.
  """
  def encabezado_usuarios, do: @encabezado_usuarios

  @doc """
  Convierte un struct Usuario en una lista de strings (fila CSV).
  """
  def usuario_a_fila(%Usuario{} = u) do
    [
      u.username,
      u.password,
      u.nombre_completo,
      Atom.to_string(u.tipo),
      u.zona,
      Atom.to_string(u.conectado)
    ]
  end

  @doc """
  Convierte una fila CSV en un struct Usuario.
  Devuelve {:ok, usuario} o {:error, motivo}.
  """
  def fila_a_usuario([username, password, nombre_completo, tipo_str, zona, conectado_str]) do
    with {:ok, tipo} <- Usuario.parsear_tipo(tipo_str),
         {:ok, conectado} <- parsear_booleano(conectado_str) do
      {:ok,
       %Usuario{
         username: username,
         password: password,
         nombre_completo: nombre_completo,
         tipo: tipo,
         zona: zona,
         conectado: conectado
       }}
    end
  end

  def fila_a_usuario(_), do: {:error, :fila_invalida}

  defp parsear_booleano("true"), do: {:ok, true}
  defp parsear_booleano("false"), do: {:ok, false}
  defp parsear_booleano(_), do: {:error, :booleano_invalido}

  # ---------- API de alto nivel para usuarios ----------

  @doc """
  Lee todos los usuarios desde data/usuarios.csv.
  Devuelve {:ok, %{username => usuario}} o {:error, motivo}.
  """
  def leer_usuarios do
    with {:ok, filas} <- leer_filas("usuarios.csv") do
      usuarios =
        filas
        |> Enum.map(&fila_a_usuario/1)
        |> Enum.reduce(%{}, fn
          {:ok, usuario}, acc -> Map.put(acc, usuario.username, usuario)
          {:error, _}, acc -> acc
        end)

      {:ok, usuarios}
    end
  end

  @doc """
  Verifica que todos los campos de texto de un usuario sean seguros para CSV
  (sin comas ni saltos de línea).
  """
  def usuario_valido_para_csv?(%Usuario{} = u) do
    Enum.all?(
      [u.username, u.password, u.nombre_completo, u.zona],
      &campo_seguro?/1
    )
  end

  @doc """
  Guarda todos los usuarios en data/usuarios.csv.

  Acepta un mapa %{username => usuario}.
  Los usuarios cuyos campos de texto no sean seguros para CSV
  se omiten (no se escriben).

  Devuelve:
  - `{:ok, escritos, omitidos}` si al menos uno se escribió.
    `omitidos` es la lista de usernames que se saltaron (puede ser `[]`).
  - `{:error, {:todos_invalidos, omitidos}}` si ninguno se pudo escribir
    y al menos había un usuario.
  - `{:error, motivo}` si falló la escritura del archivo.
  """
  def guardar_usuarios(usuarios) when is_map(usuarios) do
    {validos, omitidos} =
      Enum.split_with(usuarios, fn {_username, usuario} ->
        usuario_valido_para_csv?(usuario)
      end)

    usernames_omitidos = Enum.map(omitidos, fn {username, _} -> username end)

    case validos do
      [] when map_size(usuarios) == 0 ->
        # No había usuarios: es válido, escribe solo el encabezado
        case escribir_filas("usuarios.csv", @encabezado_usuarios, []) do
          :ok -> {:ok, 0, []}
          {:error, razon} -> {:error, razon}
        end

      [] ->
        # Había usuarios, pero todos eran inválidos
        {:error, {:todos_invalidos, usernames_omitidos}}

      _ ->
        filas = Enum.map(validos, fn {_username, usuario} -> usuario_a_fila(usuario) end)

        case escribir_filas("usuarios.csv", @encabezado_usuarios, filas) do
          :ok -> {:ok, length(filas), usernames_omitidos}
          {:error, razon} -> {:error, razon}
        end
    end
  end
end
