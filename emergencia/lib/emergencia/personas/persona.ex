defmodule Emergencia.Personas.Persona do
  @derive Jason.Encoder

  @enforce_keys [:documento, :nombre, :zona]
  defstruct [
    :documento,
    :nombre,
    :zona,
    :edad,
    estado: "sin_informacion",
    historial_estados: []
  ]

  @estados [
    "sin_informacion",
    "reportada",
    "localizada",
    "trasladada",
    "en_albergue",
    "reunificada"
  ]

  def estados, do: @estados
  def estado_valido?(estado) when is_binary(estado), do: estado in @estados
  def estado_valido?(_), do: false
end
