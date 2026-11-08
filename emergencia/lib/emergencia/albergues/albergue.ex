defmodule Emergencia.Albergues.Albergue do
  @moduledoc """
  Representa un albergue temporal para personas afectadas.
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
  Verifica si hay cupo disponible para una o más personas.
  """
  def tiene_cupo?(albergue, cantidad \\ 1)

  def tiene_cupo?(%__MODULE__{} = albergue, cantidad)
      when is_integer(cantidad) and cantidad > 0 do
    albergue.ocupacion_actual + cantidad <= albergue.capacidad_maxima
  end

  def tiene_cupo?(_, _), do: false

  @doc """
  Registra el ingreso de una persona.
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
  Registra la salida de una persona.
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
  Calcula el porcentaje de ocupación actual (0 a 100).
  """
  def porcentaje_ocupacion(%__MODULE__{capacidad_maxima: 0}), do: 0.0

  def porcentaje_ocupacion(%__MODULE__{} = albergue) do
    albergue.ocupacion_actual / albergue.capacidad_maxima * 100
  end
end
