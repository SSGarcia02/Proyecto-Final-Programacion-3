defmodule Emergencia.Personas.Persona do
  @moduledoc """
  Representa a una persona afectada por la emergencia que necesita ser localizada
  o cuya información debe ser consultada por sus familiares.

  Este módulo define la estructura de datos de una persona y las validaciones
  asociadas a sus estados. Una persona se identifica por su documento, y a lo
  largo de la emergencia puede transitar por diferentes estados (desde "sin
  información" hasta "reunificada" con su familia).

  Además del estado actual, el struct mantiene un historial de estados
  (`historial_estados`) que guarda cada cambio junto con la fecha en que ocurrió,
  permitiendo auditar la evolución del caso.
  """

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

  @doc """
  Devuelve la lista de estados válidos para una persona.

  Los estados permitidos son: `"sin_informacion"`, `"reportada"`,
  `"localizada"`, `"trasladada"`, `"en_albergue"` y `"reunificada"`.
  """
  def estados, do: @estados

  @doc """
  Verifica si un estado de persona es válido.

  ## Parámetros
  - `estado`: El estado a validar (debe ser un string).

  ## Retorna
  - `true` si el estado está en la lista de estados válidos.
  - `false` en caso contrario (incluyendo si no es un string).

  ## Ejemplos
      iex> Persona.estado_valido?("localizada")
      true

      iex> Persona.estado_valido?("desaparecida")
      false
  """
  def estado_valido?(estado) when is_binary(estado), do: estado in @estados
  def estado_valido?(_), do: false
end
