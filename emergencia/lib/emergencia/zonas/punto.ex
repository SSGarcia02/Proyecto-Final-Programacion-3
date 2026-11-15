defmodule Emergencia.Zonas.Punto do
  @moduledoc """
  Representa un punto de atención dentro de un sector (por ejemplo, una escuela,
  un parque o un edificio específico).

  Este struct es el nivel más bajo de la jerarquía geográfica del sistema:
  Zona → Sector → Punto. Cada punto registra el nombre del lugar y la cantidad
  estimada de personas afectadas en ese lugar específico.

  La suma de las personas afectadas de todos los puntos de un sector, y a su vez
  de todos los sectores de una zona, se calcula mediante la función recursiva
  `Zona.calcular_total_personas/1`.
  """

  # Permite que el struct se pueda serializar a JSON (necesario para guardar
  # los sectores y puntos anidados dentro del CSV de zonas).
  @derive Jason.Encoder

  @enforce_keys [:nombre, :personas_afectadas]
  defstruct [:nombre, :personas_afectadas]
end
