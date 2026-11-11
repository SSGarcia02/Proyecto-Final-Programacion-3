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
  def leer_filas(nombre_archivo, separador \\ ",") do
    ruta_archivo = ruta(nombre_archivo)

    case File.read(ruta_archivo) do
      {:ok, contenido} ->
        filas =
          contenido
          |> String.split("\n", trim: true)
          |> Enum.drop(1)
          # <-- Usa el separador
          |> Enum.map(&String.split(&1, separador))

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
  def escribir_filas(nombre_archivo, encabezado, filas, separador \\ ",") do
    contenido =
      [encabezado | filas]
      # <-- Usa el separador
      |> Enum.map(&Enum.join(&1, separador))
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

  # ---------- Conversión de Zona <-> fila CSV ----------

  alias Emergencia.Zonas.{Zona, Sector, Punto}

  @encabezado_zonas ["codigo", "nombre", "nivel", "sectores_json"]

  @doc """
  Devuelve el encabezado del CSV de zonas.
  """
  def encabezado_zonas, do: @encabezado_zonas

  @doc """
  Convierte un struct Zona en una lista de strings (fila CSV).
  Como los sectores son estructuras anidadas, los guardamos como texto JSON.
  """
  def zona_a_fila(%Zona{} = z) do
    [
      z.codigo,
      z.nombre,
      Atom.to_string(z.nivel),
      # Convierte la lista de sectores a un string JSON
      Jason.encode!(z.sectores)
    ]
  end

  @doc """
  Convierte una fila CSV en un struct Zona.
  """
  def fila_a_zona([codigo, nombre, nivel_str, sectores_json]) do
    with {:ok, nivel} <- Zona.parsear_nivel(nivel_str),
         {:ok, sectores_mapas} <- Jason.decode(sectores_json) do
      # Reconstruimos los structs anidados desde los mapas JSON
      sectores =
        Enum.map(sectores_mapas, fn s_map ->
          puntos =
            Enum.map(s_map["puntos"], fn p_map ->
              %Punto{
                nombre: p_map["nombre"],
                personas_afectadas: p_map["personas_afectadas"]
              }
            end)

          %Sector{nombre: s_map["nombre"], puntos: puntos}
        end)

      {:ok,
       %Zona{
         codigo: codigo,
         nombre: nombre,
         nivel: nivel,
         sectores: sectores
       }}
    end
  end

  def fila_a_zona(_), do: {:error, :fila_invalida}

  # ---------- API de alto nivel para zonas ----------

  @doc """
  Lee todas las zonas desde data/zonas.csv.
  """
  def leer_zonas do
    with {:ok, filas} <- leer_filas("zonas.csv", "|") do
      zonas =
        filas
        |> Enum.map(&fila_a_zona/1)
        |> Enum.reduce(%{}, fn
          {:ok, zona}, acc ->
            # Calculamos las personas afectadas al vuelo usando la recursividad
            zona_completa = %{zona | personas_afectadas: Zona.calcular_total_personas(zona)}
            Map.put(acc, zona_completa.codigo, zona_completa)

          {:error, _}, acc ->
            acc
        end)

      {:ok, zonas}
    end
  end

  @doc """
  Guarda todas las zonas en data/zonas.csv.
  """
  def guardar_zonas(zonas) when is_map(zonas) do
    filas = Enum.map(zonas, fn {_codigo, zona} -> zona_a_fila(zona) end)
    escribir_filas("zonas.csv", @encabezado_zonas, filas, "|")
  end

  # ---------- Conversión de Recurso <-> fila CSV ----------

  alias Emergencia.Recursos.Recurso

  @encabezado_recursos [
    "codigo",
    "nombre",
    "categoria",
    "unidad",
    "ubicacion",
    "cantidad",
    "historial_json"
  ]

  @doc """
  Devuelve el encabezado del CSV de recursos.
  """
  def encabezado_recursos, do: @encabezado_recursos

  @doc """
  Convierte un struct Recurso en una fila CSV.
  """
  def recurso_a_fila(%Recurso{} = r) do
    [
      r.codigo,
      r.nombre,
      r.categoria,
      r.unidad,
      r.ubicacion,
      to_string(r.cantidad),
      Jason.encode!(r.historial)
    ]
  end

  @doc """
  Convierte una fila CSV en un struct Recurso.
  """
  def fila_a_recurso([codigo, nombre, categoria, unidad, ubicacion, cantidad_str, historial_json]) do
    with {cantidad, ""} <- Integer.parse(cantidad_str),
         {:ok, historial} <- Jason.decode(historial_json) do
      {:ok,
       %Recurso{
         codigo: codigo,
         nombre: nombre,
         categoria: categoria,
         unidad: unidad,
         ubicacion: ubicacion,
         cantidad: cantidad,
         historial: historial
       }}
    else
      _ -> {:error, :fila_invalida}
    end
  end

  def fila_a_recurso(_), do: {:error, :fila_invalida}

  @doc """
  Lee todos los recursos desde data/recursos.csv.
  Usa el separador "|" para evitar conflictos con el JSON.
  """
  def leer_recursos do
    with {:ok, filas} <- leer_filas("recursos.csv", "|") do
      recursos =
        filas
        |> Enum.map(&fila_a_recurso/1)
        |> Enum.reduce(%{}, fn
          {:ok, recurso}, acc -> Map.put(acc, recurso.codigo, recurso)
          {:error, _}, acc -> acc
        end)

      {:ok, recursos}
    end
  end

  @doc """
  Guarda todos los recursos en data/recursos.csv.
  """
  def guardar_recursos(recursos) when is_map(recursos) do
    filas = Enum.map(recursos, fn {_codigo, r} -> recurso_a_fila(r) end)
    escribir_filas("recursos.csv", @encabezado_recursos, filas, "|")
  end

  # ---------- Conversión de Necesidad <-> fila CSV ----------

  alias Emergencia.Necesidades.Necesidad

  @encabezado_necesidades [
    "id",
    "tipo",
    "cantidad_requerida",
    "zona",
    "prioridad",
    "descripcion",
    "responsable",
    "asociado_a",
    "estado",
    "recurso_asignado",
    "fecha_creacion"
  ]

  def encabezado_necesidades, do: @encabezado_necesidades

  def necesidad_a_fila(%Necesidad{} = n) do
    [
      n.id,
      Atom.to_string(n.tipo),
      to_string(n.cantidad_requerida),
      n.zona,
      Atom.to_string(n.prioridad),
      n.descripcion,
      n.responsable,
      n.asociado_a || "",
      n.estado,
      n.recurso_asignado || "",
      n.fecha_creacion || ""
    ]
  end

  def fila_a_necesidad([
        id,
        tipo_str,
        cant_str,
        zona,
        prio_str,
        desc,
        resp,
        asociado,
        estado,
        rec_asig,
        fecha
      ]) do
    with {:ok, tipo} <- Necesidad.parsear_tipo(tipo_str),
         {:ok, prioridad} <- Necesidad.parsear_prioridad(prio_str),
         {cantidad, ""} <- Integer.parse(cant_str) do
      {:ok,
       %Necesidad{
         id: id,
         tipo: tipo,
         cantidad_requerida: cantidad,
         zona: zona,
         prioridad: prioridad,
         descripcion: desc,
         responsable: resp,
         asociado_a: if(asociado == "", do: nil, else: asociado),
         estado: estado,
         recurso_asignado: if(rec_asig == "", do: nil, else: rec_asig),
         fecha_creacion: fecha
       }}
    else
      _ -> {:error, :fila_invalida}
    end
  end

  def fila_a_necesidad(_), do: {:error, :fila_invalida}

  def leer_necesidades do
    with {:ok, filas} <- leer_filas("necesidades.csv", "|") do
      necesidades =
        filas
        |> Enum.map(&fila_a_necesidad/1)
        |> Enum.reduce(%{}, fn
          {:ok, nec}, acc -> Map.put(acc, nec.id, nec)
          {:error, _}, acc -> acc
        end)

      {:ok, necesidades}
    end
  end

  def guardar_necesidades(necesidades) when is_map(necesidades) do
    filas = Enum.map(necesidades, fn {_id, n} -> necesidad_a_fila(n) end)
    escribir_filas("necesidades.csv", @encabezado_necesidades, filas, "|")
  end

  # ---------- Conversión de Albergue <-> fila CSV ----------

  alias Emergencia.Albergues.Albergue

  @encabezado_albergues [
    "codigo",
    "nombre",
    "zona",
    "capacidad_maxima",
    "ocupacion_actual",
    "personas_json",
    "recursos_json",
    "necesidades_json"
  ]

  def encabezado_albergues, do: @encabezado_albergues

  def albergue_a_fila(%Albergue{} = a) do
    [
      a.codigo,
      a.nombre,
      a.zona,
      to_string(a.capacidad_maxima),
      to_string(a.ocupacion_actual),
      Jason.encode!(a.personas),
      Jason.encode!(a.recursos),
      Jason.encode!(a.necesidades)
    ]
  end

  def fila_a_albergue([
        codigo,
        nombre,
        zona,
        cap_str,
        ocu_str,
        personas_json,
        recursos_json,
        necesidades_json
      ]) do
    with {capacidad, ""} <- Integer.parse(cap_str),
         {ocupacion, ""} <- Integer.parse(ocu_str),
         {:ok, personas} <- Jason.decode(personas_json),
         {:ok, recursos} <- Jason.decode(recursos_json),
         {:ok, necesidades} <- Jason.decode(necesidades_json) do
      {:ok,
       %Albergue{
         codigo: codigo,
         nombre: nombre,
         zona: zona,
         capacidad_maxima: capacidad,
         ocupacion_actual: ocupacion,
         personas: personas,
         recursos: recursos,
         necesidades: necesidades
       }}
    else
      _ -> {:error, :fila_invalida}
    end
  end

  def fila_a_albergue(_), do: {:error, :fila_invalida}

  def leer_albergues do
    # Usamos "|" como separador para evitar conflictos con el JSON
    with {:ok, filas} <- leer_filas("albergues.csv", "|") do
      albergues =
        filas
        |> Enum.map(&fila_a_albergue/1)
        |> Enum.reduce(%{}, fn
          {:ok, albergue}, acc -> Map.put(acc, albergue.codigo, albergue)
          {:error, _}, acc -> acc
        end)

      {:ok, albergues}
    end
  end

  def guardar_albergues(albergues) when is_map(albergues) do
    filas = Enum.map(albergues, fn {_codigo, a} -> albergue_a_fila(a) end)
    escribir_filas("albergues.csv", @encabezado_albergues, filas, "|")
  end

  # ---------- Conversión de Persona <-> fila CSV ----------
  alias Emergencia.Personas.{Persona, Mensaje}

  @encabezado_personas ["documento", "nombre", "zona", "edad", "estado", "historial_json"]

  def encabezado_personas, do: @encabezado_personas

  def persona_a_fila(%Persona{} = p) do
    [
      p.documento,
      p.nombre,
      p.zona,
      to_string(p.edad || ""),
      p.estado,
      Jason.encode!(p.historial_estados)
    ]
  end

  def fila_a_persona([documento, nombre, zona, edad_str, estado, historial_json]) do
    with {:ok, historial} <- Jason.decode(historial_json) do
      edad = if edad_str == "", do: nil, else: String.to_integer(edad_str)

      {:ok,
       %Persona{
         documento: documento,
         nombre: nombre,
         zona: zona,
         edad: edad,
         estado: estado,
         historial_estados: historial
       }}
    else
      _ -> {:error, :fila_invalida}
    end
  end

  def fila_a_persona(_), do: {:error, :fila_invalida}

  def leer_personas do
    with {:ok, filas} <- leer_filas("personas.csv", "|") do
      personas =
        filas
        |> Enum.map(&fila_a_persona/1)
        |> Enum.reduce(%{}, fn
          {:ok, p}, acc -> Map.put(acc, p.documento, p)
          {:error, _}, acc -> acc
        end)

      {:ok, personas}
    end
  end

  def guardar_personas(personas) when is_map(personas) do
    filas = Enum.map(personas, fn {_doc, p} -> persona_a_fila(p) end)
    escribir_filas("personas.csv", @encabezado_personas, filas, "|")
  end

  # ---------- Conversión de Mensaje <-> fila CSV ----------
  @encabezado_mensajes ["id", "documento_destino", "remitente", "contenido", "leido", "fecha"]

  def encabezado_mensajes, do: @encabezado_mensajes

  def mensaje_a_fila(%Mensaje{} = m) do
    [
      m.id,
      m.documento_destino,
      m.remitente,
      m.contenido,
      to_string(m.leido),
      m.fecha || ""
    ]
  end

  def fila_a_mensaje([id, doc, remitente, contenido, leido_str, fecha]) do
    leido = leido_str == "true"

    {:ok,
     %Mensaje{
       id: id,
       documento_destino: doc,
       remitente: remitente,
       contenido: contenido,
       leido: leido,
       fecha: fecha
     }}
  end

  def fila_a_mensaje(_), do: {:error, :fila_invalida}

  def leer_mensajes do
    with {:ok, filas} <- leer_filas("mensajes.csv", "|") do
      mensajes =
        filas
        |> Enum.map(&fila_a_mensaje/1)
        |> Enum.reduce(%{}, fn
          {:ok, m}, acc -> Map.put(acc, m.id, m)
          {:error, _}, acc -> acc
        end)

      {:ok, mensajes}
    end
  end

  def guardar_mensajes(mensajes) when is_map(mensajes) do
    filas = Enum.map(mensajes, fn {_id, m} -> mensaje_a_fila(m) end)
    escribir_filas("mensajes.csv", @encabezado_mensajes, filas, "|")
  end

  # ---------- Conversión de Mascota <-> fila CSV ----------

  alias Emergencia.Mascotas.Mascota

  @encabezado_mascotas [
    "id",
    "tipo_reporte",
    "especie",
    "nombre",
    "caracteristicas",
    "color",
    "tamano",
    "zona",
    "contacto",
    "estado",
    "reporte_vinculado"
  ]

  def encabezado_mascotas, do: @encabezado_mascotas

  def mascota_a_fila(%Mascota{} = m) do
    [
      m.id,
      m.tipo_reporte,
      m.especie,
      m.nombre || "",
      m.caracteristicas || "",
      m.color || "",
      m.tamano || "",
      m.zona,
      m.contacto,
      m.estado,
      m.reporte_vinculado || ""
    ]
  end

  def fila_a_mascota([
        id,
        tipo,
        especie,
        nombre,
        caract,
        color,
        tamano,
        zona,
        contacto,
        estado,
        vinculado
      ]) do
    {:ok,
     %Mascota{
       id: id,
       tipo_reporte: tipo,
       especie: especie,
       nombre: if(nombre == "", do: nil, else: nombre),
       caracteristicas: if(caract == "", do: nil, else: caract),
       color: if(color == "", do: nil, else: color),
       tamano: if(tamano == "", do: nil, else: tamano),
       zona: zona,
       contacto: contacto,
       estado: estado,
       reporte_vinculado: if(vinculado == "", do: nil, else: vinculado)
     }}
  end

  def fila_a_mascota(_), do: {:error, :fila_invalida}

  def leer_mascotas do
    # Usamos "|" porque las características pueden tener comas
    with {:ok, filas} <- leer_filas("mascotas.csv", "|") do
      mascotas =
        filas
        |> Enum.map(&fila_a_mascota/1)
        |> Enum.reduce(%{}, fn
          {:ok, m}, acc -> Map.put(acc, m.id, m)
          {:error, _}, acc -> acc
        end)

      {:ok, mascotas}
    end
  end

  def guardar_mascotas(mascotas) when is_map(mascotas) do
    filas = Enum.map(mascotas, fn {_id, m} -> mascota_a_fila(m) end)
    escribir_filas("mascotas.csv", @encabezado_mascotas, filas, "|")
  end

  # ---------- Conversión de Actividad <-> fila CSV ----------

  @encabezado_actividad ["fecha", "username", "accion"]

  def encabezado_actividad, do: @encabezado_actividad

  def actividad_a_fila(actividad) do
    [actividad.fecha, actividad.username, actividad.accion]
  end

  def leer_actividad do
    with {:ok, filas} <- leer_filas("actividad.csv", "|") do
      actividades =
        filas
        |> Enum.map(fn [fecha, username, accion] ->
          %{fecha: fecha, username: username, accion: accion}
        end)

      {:ok, actividades}
    end
  end

  def registrar_actividad(username, accion) do
    fecha = DateTime.utc_now() |> DateTime.to_string()
    nueva_actividad = %{fecha: fecha, username: username, accion: accion}

    # Leemos lo que hay, agregamos la nueva y guardamos
    case leer_actividad() do
      {:ok, actividades} ->
        filas = Enum.map([nueva_actividad | actividades], &actividad_a_fila/1)
        escribir_filas("actividad.csv", @encabezado_actividad, filas, "|")

      _ ->
        :ok
    end
  end
end
