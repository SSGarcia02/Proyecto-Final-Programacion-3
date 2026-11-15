defmodule Emergencia.Zonas.Sector do
  @moduledoc """
  Representa un sector dentro de una zona afectada, que agrupa varios puntos de
  atención.

  Este struct es el nivel intermedio de la jerarquía geográfica del sistema:
  Zona → Sector → Punto. Un sector contiene una lista de puntos (por ejemplo,
  un sector "Centro" puede contener los puntos "Escuela Central", "Parque Sur"
  y "Hospital Norte").

  Los sectores permiten organizar la información de una zona de manera más
  granular y son utilizados por la función recursiva `Zona.calcular_total_personas/1`
  para sumar las personas afectadas de todos los puntos de todos los sectores.
  """

  # Permite que el struct se pueda serializar a JSON (necesario para guardar
  # los sectores y puntos anidados dentro del CSV de zonas).
  @derive Jason.Encoder

  @enforce_keys [:nombre]
  defstruct [:nombre, puntos: []]
end
