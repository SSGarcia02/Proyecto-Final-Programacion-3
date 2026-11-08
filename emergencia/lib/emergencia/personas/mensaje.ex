defmodule Emergencia.Personas.Mensaje do
  @derive Jason.Encoder

  @enforce_keys [:id, :documento_destino, :remitente, :contenido]
  defstruct [
    :id,
    :documento_destino,
    :remitente,
    :contenido,
    leido: false,
    fecha: nil
  ]
end
