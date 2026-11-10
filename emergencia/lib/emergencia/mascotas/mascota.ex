defmodule Emergencia.Mascotas.Mascota do
  @moduledoc """
  Representa un reporte de mascota perdida o encontrada.
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

  def tipos, do: @tipos
  def especies, do: @especies
  def tamanos, do: @tamanos
  def estados, do: @estados

  @doc """
  Calcula un puntaje de similitud (0 a 100) entre dos reportes.
  Solo compara reportes de distinto tipo (perdida vs encontrada).
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
