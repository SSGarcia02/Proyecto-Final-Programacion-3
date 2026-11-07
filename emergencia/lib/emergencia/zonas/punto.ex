defmodule Emergencia.Zonas.Punto do
  @moduledoc """
  Un punto de atención dentro de un sector (ej. una escuela, un parque).
  """
  @derive Jason.Encoder
  @enforce_keys [:nombre, :personas_afectadas]
  defstruct [:nombre, :personas_afectadas]
end
