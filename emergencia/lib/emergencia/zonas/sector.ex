defmodule Emergencia.Zonas.Sector do
  @moduledoc """
  Un sector dentro de una zona, que agrupa varios puntos de atención.
  """
  @derive Jason.Encoder
  @enforce_keys [:nombre]
  defstruct [:nombre, puntos: []]
end
