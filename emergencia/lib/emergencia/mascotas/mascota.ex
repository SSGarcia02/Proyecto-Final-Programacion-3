defmodule Emergencia.Mascotas.Mascota do
  @moduledoc """
  Representa un reporte de mascota perdida o encontrada durante la emergencia.

  Este módulo define la estructura de datos de un reporte de mascota y contiene
  el algoritmo puro de similitud que compara dos reportes para determinar si
  podrían corresponder a la misma mascota.
  
  El algoritmo de coincidencia evalúa cuatro atributos (especie, zona, color y
  tamaño) y produce un puntaje de 0 a 100. Solo se comparan reportes de distinto
  tipo (una mascota perdida con una encontrada), ya que dos reportes del mismo
  tipo no pueden ser complementarios.
  """

  @derive Jason.Encoder

  @enforce_keys [:id, :tipo_reporte, :especie, :zona, :contacto]
  defstruct [
    :id,
    :tipo_reporte,
    :especie,
    :nombre,
    :caracteristicas,
    :color,
    :tamano,
    :zona,
    :contacto,
    estado: "activa",
    reporte_vinculado: nil
  ]

  @tipos ["perdida", "encontrada"]
  @especies ["perro", "gato", "otro"]
  @tamanos ["pequeño", "mediano", "grande"]
  @estados ["activa", "posible_coincidencia", "resuelta"]

  @doc """
  Devuelve la lista de tipos de reporte válidos: `["perdida", "encontrada"]`.
  """
  def tipos, do: @tipos

  @doc """
  Devuelve la lista de especies válidas: `["perro", "gato", "otro"]`.
  """
  def especies, do: @especies

  @doc """
  Devuelve la lista de tamaños válidos: `["pequeño", "mediano", "grande"]`.
  """
  def tamanos, do: @tamanos

  @doc """
  Devuelve la lista de estados válidos: `["activa", "posible_coincidencia", "resuelta"]`.
  """
  def estados, do: @estados

  @doc """
  Calcula un puntaje de similitud (0 a 100) entre dos reportes de mascota.

  El algoritmo compara dos reportes que deben ser de distinto tipo (una perdida
  y una encontrada). Si ambos reportes son del mismo tipo, retorna 0 porque no
  tiene sentido buscar coincidencias entre dos perdidas o dos encontradas.

  La puntuación se distribuye de la siguiente manera:
  - **Misma especie (30 puntos):** Es el atributo más importante para identificar
    que se trata del mismo animal.
  - **Misma zona (30 puntos):** Indica que la mascota fue vista en el mismo sector.
  - **Mismo color (20 puntos):** Un rasgo visual relevante.
  - **Mismo tamaño (20 puntos):** Un rasgo visual complementario.

  El puntaje máximo posible es 100 (cuando los cuatro atributos coinciden) y el
  mínimo es 0 (cuando no coincide ninguno o los tipos son iguales). En el
  GenServer de Mascotas, se considera una "posible coincidencia" si el puntaje
  es mayor o igual a 50.

  ## Parámetros
  - `m1`: Primer struct `%Mascota{}` (generalmente la mascota perdida).
  - `m2`: Segundo struct `%Mascota{}` (generalmente la mascota encontrada).

  ## Retorna
  - Un número entero entre 0 y 100 que representa el puntaje de similitud.

  ## Ejemplos
      iex> perdida = %Mascota{tipo_reporte: "perdida", especie: "perro", zona: "Z001", color: "negro", tamano: "mediano"}
      iex> encontrada = %Mascota{tipo_reporte: "encontrada", especie: "perro", zona: "Z001", color: "negro", tamano: "mediano"}
      iex> Mascota.calcular_coincidencia(perdida, encontrada)
      100

      iex> Mascota.calcular_coincidencia(perdida, perdida)
      0
  """
  def calcular_coincidencia(
        %__MODULE__{tipo_reporte: t1} = m1,
        %__MODULE__{tipo_reporte: t2} = m2
      ) do
    if t1 == t2 do
      0
    else
      puntos = 0

      # Misma especie (30 pts)
      puntos = if m1.especie == m2.especie, do: puntos + 30, else: puntos

      # Misma zona (30 pts)
      puntos = if m1.zona == m2.zona, do: puntos + 30, else: puntos

      # Mismo color (20 pts)
      color1 = String.downcase(m1.color || "")
      color2 = String.downcase(m2.color || "")
      puntos = if color1 != "" and color1 == color2, do: puntos + 20, else: puntos

      # Mismo tamaño (20 pts)
      puntos = if m1.tamano == m2.tamano, do: puntos + 20, else: puntos

      puntos
    end
  end
end
