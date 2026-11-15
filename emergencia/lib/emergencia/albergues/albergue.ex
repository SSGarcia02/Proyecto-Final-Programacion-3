defmodule Emergencia.Albergues.Albergue do
  @moduledoc """
  Representa un albergue temporal para personas afectadas por la emergencia.

  Este módulo define la estructura de datos de un albergue y las funciones puras
  que operan sobre él. Un albergue tiene una capacidad máxima y lleva un control
  de la ocupación actual, la lista de personas alojadas (por documento), los
  recursos asociados y las necesidades asociadas.

  Las funciones de este módulo no tienen efectos secundarios (son puras):
  reciben un struct `Albergue` y devuelven una tupla `{:ok, nuevo_albergue}` o
  `{:error, motivo}`, sin modificar el estado global ni persistir en disco.
  """

  @derive Jason.Encoder

  @enforce_keys [:codigo, :nombre, :zona, :capacidad_maxima]
  defstruct [
    :codigo,
    :nombre,
    :zona,
    :capacidad_maxima,
    ocupacion_actual: 0,
    personas: [],
    recursos: [],
    necesidades: []
  ]

  @doc """
  Verifica si hay cupo disponible en el albergue para una o más personas.

  ## Parámetros
  - `albergue`: El struct `%Albergue{}` a evaluar.
  - `cantidad`: Número entero positivo de personas que se desean ingresar (por defecto 1).

  ## Retorna
  - `true` si la ocupación actual más la cantidad solicitada no supera la capacidad máxima.
  - `false` en caso contrario (o si los argumentos no son válidos).

  ## Ejemplos
      iex> albergue = %Albergue{capacidad_maxima: 50, ocupacion_actual: 40}
      iex> Albergue.tiene_cupo?(albergue, 10)
      true

      iex> Albergue.tiene_cupo?(albergue, 11)
      false
  """
  def tiene_cupo?(albergue, cantidad \\ 1)

  def tiene_cupo?(%__MODULE__{} = albergue, cantidad)
      when is_integer(cantidad) and cantidad > 0 do
    albergue.ocupacion_actual + cantidad <= albergue.capacidad_maxima
  end

  def tiene_cupo?(_, _), do: false

  @doc """
  Registra el ingreso de una persona al albergue.

  Valida dos condiciones antes de modificar el albergue:
  1. Que la persona no esté ya registrada en el albergue (evita duplicados).
  2. Que haya cupo disponible (usando `tiene_cupo?/2`).

  Si ambas condiciones se cumplen, incrementa la ocupación actual en 1 y
  agrega el documento de la persona a la lista `personas`.

  ## Parámetros
  - `albergue`: El struct `%Albergue{}` a modificar.
  - `documento`: El documento de identidad de la persona (string).

  ## Retorna
  - `{:ok, nuevo_albergue}` si el ingreso es exitoso.
  - `{:error, :ya_esta_en_albergue}` si la persona ya estaba registrada.
  - `{:error, :sin_cupo}` si el albergue alcanzó su capacidad máxima.
  """
  def ingresar(%__MODULE__{} = albergue, documento) do
    cond do
      documento in albergue.personas ->
        {:error, :ya_esta_en_albergue}

      tiene_cupo?(albergue, 1) ->
        nuevo_albergue = %{
          albergue
          | ocupacion_actual: albergue.ocupacion_actual + 1,
            personas: [documento | albergue.personas]
        }

        {:ok, nuevo_albergue}

      true ->
        {:error, :sin_cupo}
    end
  end

  @doc """
  Registra la salida de una persona del albergue.

  Verifica que la persona esté efectivamente registrada en el albergue.
  Si es así, decrementa la ocupación actual en 1 y elimina el documento
  de la lista `personas`.

  ## Parámetros
  - `albergue`: El struct `%Albergue{}` a modificar.
  - `documento`: El documento de identidad de la persona (string).

  ## Retorna
  - `{:ok, nuevo_albergue}` si la salida es exitosa.
  - `{:error, :no_esta_en_albergue}` si la persona no está registrada en el albergue.
  """
  def egresar(%__MODULE__{} = albergue, documento) do
    if documento in albergue.personas do
      nuevo_albergue = %{
        albergue
        | ocupacion_actual: albergue.ocupacion_actual - 1,
          personas: List.delete(albergue.personas, documento)
      }

      {:ok, nuevo_albergue}
    else
      {:error, :no_esta_en_albergue}
    end
  end

  @doc """
  Calcula el porcentaje de ocupación actual del albergue (0 a 100).

  La fórmula es: `(ocupacion_actual / capacidad_maxima) * 100`.
  Si la capacidad máxima es 0, retorna 0.0 para evitar una división por cero.

  ## Parámetros
  - `albergue`: El struct `%Albergue{}` a evaluar.

  ## Retorna
  - Un número flotante entre 0.0 y 100.0 que representa el porcentaje de ocupación.

  ## Ejemplos
      iex> albergue = %Albergue{capacidad_maxima: 50, ocupacion_actual: 25}
      iex> Albergue.porcentaje_ocupacion(albergue)
      50.0
  """
  def porcentaje_ocupacion(%__MODULE__{capacidad_maxima: 0}), do: 0.0

  def porcentaje_ocupacion(%__MODULE__{} = albergue) do
    albergue.ocupacion_actual / albergue.capacidad_maxima * 100
  end
end
