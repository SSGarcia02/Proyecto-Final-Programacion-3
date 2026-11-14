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

  @categorias [
    :agua,
    :alimentos,
    :medicamentos,
    :primeros_auxilios,
    :refugio,
    :transporte,
    :rescate,
    :otra
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

  @doc """
  Transfiere cantidad de un recurso origen a un recurso destino.
  Ambos recursos deben ser de la misma categoría y unidad.
  Devuelve {:ok, recurso_origen_actualizado, recurso_destino_actualizado} o {:error, motivo}.
  """
  def transferir(%__MODULE__{} = origen, %__MODULE__{} = destino, cantidad)
      when is_integer(cantidad) and cantidad > 0 do
    cond do
      origen.codigo == destino.codigo ->
        {:error, :mismo_recurso}

      origen.categoria != destino.categoria ->
        {:error, :categoria_incompatible}

      origen.cantidad < cantidad ->
        {:error, :sin_existencias}

      true ->
        movimiento_salida = %{
          tipo: "transferencia_salida",
          cantidad: cantidad,
          fecha: DateTime.utc_now() |> DateTime.to_string(),
          destino: destino.ubicacion
        }

        movimiento_entrada = %{
          tipo: "transferencia_entrada",
          cantidad: cantidad,
          fecha: DateTime.utc_now() |> DateTime.to_string(),
          origen: origen.ubicacion
        }

        origen_actualizado = %{
          origen
          | cantidad: origen.cantidad - cantidad,
            historial: [movimiento_salida | origen.historial]
        }

        destino_actualizado = %{
          destino
          | cantidad: destino.cantidad + cantidad,
            historial: [movimiento_entrada | destino.historial]
        }

        {:ok, origen_actualizado, destino_actualizado}
    end
  end

  def transferir(_, _, _), do: {:error, :cantidad_invalida}

  def categorias, do: @categorias

  def categoria_valida?(cat) when is_atom(cat), do: cat in @categorias
  def categoria_valida?(_), do: false

  def parsear_categoria(texto) when is_binary(texto) do
    cat =
      texto |> String.trim() |> String.downcase() |> String.replace(" ", "_") |> String.to_atom()

    if categoria_valida?(cat), do: {:ok, cat}, else: {:error, :categoria_invalida}
  end
end
