defmodule Emergencia.Recursos.Recurso do
  @moduledoc """
  Representa un recurso o suministro (agua, alimentos, medicamentos, etc.) que se
  administra en un centro de apoyo (centro de acopio, albergue o punto de atención).

  Este módulo define la estructura de datos de un recurso y las funciones puras
  que gestionan su inventario:
  - `ingresar/2`: aumenta la cantidad disponible.
  - `egresar/2`: disminuye la cantidad disponible, impidiendo valores negativos.
  - `transferir/3`: mueve unidades de un recurso a otro de la misma categoría.

  Todas las funciones registran cada movimiento en el campo `historial` con la
  fecha y el tipo de operación. Además, las operaciones de egreso y transferencia
  validan que haya suficientes existencias antes de modificar el recurso, lo que
  garantiza que la cantidad nunca sea negativa.
  """

  # Necesario para guardar el historial en formato JSON dentro del CSV
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
  Registra una entrada de inventario, sumando la cantidad indicada al recurso.

  Crea un movimiento de tipo `"entrada"` con la fecha actual y lo agrega al
  inicio del historial.

  ## Parámetros
  - `recurso`: El struct `%Recurso{}` a modificar.
  - `cantidad`: Número entero positivo de unidades a ingresar.

  ## Retorna
  - `{:ok, nuevo_recurso}` si la cantidad es válida (entero > 0).
  - `{:error, :cantidad_invalida}` si la cantidad no es un entero positivo.

  ## Ejemplos
      iex> recurso = %Recurso{cantidad: 10, historial: []}
      iex> {:ok, nuevo} = Recurso.ingresar(recurso, 5)
      iex> nuevo.cantidad
      15
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
  Registra una salida de inventario, restando la cantidad indicada al recurso.

  Antes de modificar el recurso, verifica que haya suficientes existencias. Si
  las hay, crea un movimiento de tipo `"salida"` con la fecha actual y lo agrega
  al historial.

  ## Parámetros
  - `recurso`: El struct `%Recurso{}` a modificar.
  - `cantidad`: Número entero positivo de unidades a egresar.

  ## Retorna
  - `{:ok, nuevo_recurso}` si hay suficientes existencias.
  - `{:error, :sin_existencias}` si la cantidad solicitada supera el inventario.
  - `{:error, :cantidad_invalida}` si la cantidad no es un entero positivo.

  ## Ejemplos
      iex> recurso = %Recurso{cantidad: 10, historial: []}
      iex> {:ok, nuevo} = Recurso.egresar(recurso, 3)
      iex> nuevo.cantidad
      7

      iex> Recurso.egresar(recurso, 15)
      {:error, :sin_existencias}
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
  Transfiere una cantidad de un recurso origen a un recurso destino.

  Esta función valida tres condiciones antes de realizar la transferencia:
  1. Que el origen y el destino no sean el mismo recurso.
  2. Que ambos recursos pertenezcan a la misma categoría.
  3. Que el origen tenga suficientes existencias.

  Si todas las validaciones pasan, resta la cantidad del origen, la suma al
  destino y registra el movimiento en el historial de ambos recursos.

  ## Parámetros
  - `origen`: El struct `%Recurso{}` de donde sale la mercancía.
  - `destino`: El struct `%Recurso{}` que recibe la mercancía.
  - `cantidad`: Número entero positivo de unidades a transferir.

  ## Retorna
  - `{:ok, origen_actualizado, destino_actualizado}` si la transferencia es exitosa.
  - `{:error, :mismo_recurso}` si el origen y el destino tienen el mismo código.
  - `{:error, :categoria_incompatible}` si las categorías no coinciden.
  - `{:error, :sin_existencias}` si el origen no tiene suficientes unidades.
  - `{:error, :cantidad_invalida}` si la cantidad no es un entero positivo.
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

  @doc """
  Devuelve la lista de categorías válidas para un recurso.
  """
  def categorias, do: @categorias

  @doc """
  Verifica si una categoría de recurso es válida.

  ## Parámetros
  - `cat`: La categoría a validar (debe ser un átomo).

  ## Retorna
  - `true` si la categoría está en la lista de categorías válidas.
  - `false` en caso contrario.
  """
  def categoria_valida?(cat) when is_atom(cat), do: cat in @categorias
  def categoria_valida?(_), do: false

  @doc """
  Convierte un string en una categoría de recurso válida (átomo).

  Normaliza el texto eliminando espacios, convirtiéndolo a minúsculas y
  reemplazando espacios por guiones bajos antes de convertirlo a átomo.

  ## Parámetros
  - `texto`: El string a convertir (ej. `"Primeros Auxilios"`).

  ## Retorna
  - `{:ok, categoria}` si el texto corresponde a una categoría válida.
  - `{:error, :categoria_invalida}` en caso contrario.
  """
  def parsear_categoria(texto) when is_binary(texto) do
    cat =
      texto |> String.trim() |> String.downcase() |> String.replace(" ", "_") |> String.to_atom()

    if categoria_valida?(cat), do: {:ok, cat}, else: {:error, :categoria_invalida}
  end
end
