defmodule Emergencia.Personas.Mensaje do
  @moduledoc """
  Representa un mensaje dirigido a una persona afectada (damnificado) por parte
  de un familiar o conocido.

  Este módulo define la estructura de datos de un mensaje dentro del sistema de
  comunicación entre familiares. Los mensajes se almacenan en el GenServer de
  Personas y se persisten en el archivo `data/mensajes.csv`.

  Un mensaje tiene un identificador único, el documento de la persona
  destinataria, el nombre del remitente, el contenido del mensaje, un estado de
  lectura (leído o pendiente) y la fecha en que fue enviado.
  """

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
