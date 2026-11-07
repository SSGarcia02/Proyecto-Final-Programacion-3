defmodule Emergencia.Recursos.Recurso do
  @moduledoc """
  Representa un recurso o suministro en un centro de apoyo.
  """
  # Necesario para guardar el historial en JSON
  @derive Jason.Encoder

  @enforce_keys [:codigo, :nombre, :categoria, :unidad, :ubicacion]
  defstruct [
    :codigo,
    :nombre,
    :categoria,
    :unidad,
    :ubicacion,
    cantidad: 0,
    historial: []
  ]

  @doc """
  Registra una entrada de inventario (suma cantidad) y la guarda en el historial.
  """
  def ingresar(%__MODULE__{} = recurso, cantidad) when is_integer(cantidad) and cantidad > 0 do
    movimiento = %{
      tipo: "entrada",
      cantidad: cantidad,
      fecha: DateTime.utc_now() |> DateTime.to_string()
    }

    nuevo_recurso = %{
      recurso
      | cantidad: recurso.cantidad + cantidad,
        historial: [movimiento | recurso.historial]
    }

    {:ok, nuevo_recurso}
  end

  def ingresar(%__MODULE__{}, _cantidad), do: {:error, :cantidad_invalida}

  @doc """
  Registra una salida de inventario (resta cantidad).
  Evita que la cantidad quede en negativo.
  """
  def egresar(%__MODULE__{} = recurso, cantidad) when is_integer(cantidad) and cantidad > 0 do
    if recurso.cantidad >= cantidad do
      movimiento = %{
        tipo: "salida",
        cantidad: cantidad,
        fecha: DateTime.utc_now() |> DateTime.to_string()
      }

      nuevo_recurso = %{
        recurso
        | cantidad: recurso.cantidad - cantidad,
          historial: [movimiento | recurso.historial]
      }

      {:ok, nuevo_recurso}
    else
      {:error, :sin_existencias}
    end
  end

  def egresar(%__MODULE__{}, _cantidad), do: {:error, :cantidad_invalida}
end
