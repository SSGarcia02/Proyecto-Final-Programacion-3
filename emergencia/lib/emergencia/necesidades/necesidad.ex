defmodule Emergencia.Necesidades.Necesidad do
  @moduledoc """
  Representa una solicitud de ayuda (necesidad) en una zona afectada por la emergencia.

  Este módulo define la estructura de datos de una necesidad y las funciones puras
  que validan y transforman sus atributos. Una necesidad tiene un identificador
  único, un tipo (agua, alimentos, etc.), una cantidad requerida, una zona, una
  prioridad, una descripción, un responsable, el estado actual y el recurso
  asignado (si lo tiene).

  Las funciones de este módulo no tienen efectos secundarios: validan datos y
  devuelven tuplas `{:ok, valor}` o `{:error, motivo}`.
  """

  @derive Jason.Encoder

  @enforce_keys [:id, :tipo, :cantidad_requerida, :zona, :prioridad, :descripcion, :responsable]
  defstruct [
    :id,
    :tipo,
    :cantidad_requerida,
    :zona,
    :prioridad,
    :descripcion,
    :responsable,
    :asociado_a,
    estado: "pendiente",
    recurso_asignado: nil,
    fecha_creacion: nil
  ]

  @tipos [
    :agua,
    :alimentos,
    :medicamentos,
    :primeros_auxilios,
    :refugio,
    :transporte,
    :rescate,
    :otra
  ]
  @prioridades [:critica, :alta, :media, :baja]
  @estados ["pendiente", "asignada", "en_atencion", "atendida", "cancelada"]

  @doc """
  Devuelve la lista de tipos de necesidad válidos.

  Los tipos se representan como átomos: `:agua`, `:alimentos`, `:medicamentos`,
  `:primeros_auxilios`, `:refugio`, `:transporte`, `:rescate` y `:otra`.
  """
  def tipos, do: @tipos

  @doc """
  Devuelve la lista de prioridades válidas: `[:critica, :alta, :media, :baja]`.
  """
  def prioridades, do: @prioridades

  @doc """
  Devuelve la lista de estados válidos para una necesidad.

  Los estados son strings: `"pendiente"`, `"asignada"`, `"en_atencion"`,
  `"atendida"` y `"cancelada"`.
  """
  def estados, do: @estados

  @doc """
  Verifica si un tipo de necesidad es válido.

  ## Parámetros
  - `tipo`: El tipo a validar (debe ser un átomo).

  ## Retorna
  - `true` si el tipo está en la lista de tipos válidos.
  - `false` en caso contrario (incluyendo si no es un átomo).
  """
  def tipo_valido?(tipo) when is_atom(tipo), do: tipo in @tipos
  def tipo_valido?(_), do: false

  @doc """
  Verifica si una prioridad es válida.

  ## Parámetros
  - `prio`: La prioridad a validar (debe ser un átomo).

  ## Retorna
  - `true` si la prioridad está en la lista de prioridades válidas.
  - `false` en caso contrario.
  """
  def prioridad_valida?(prio) when is_atom(prio), do: prio in @prioridades
  def prioridad_valida?(_), do: false

  @doc """
  Verifica si un estado de necesidad es válido.

  ## Parámetros
  - `estado`: El estado a validar (debe ser un string).

  ## Retorna
  - `true` si el estado está en la lista de estados válidos.
  - `false` en caso contrario.
  """
  def estado_valido?(estado) when is_binary(estado), do: estado in @estados
  def estado_valido?(_), do: false

  @doc """
  Convierte un string en un tipo de necesidad válido (átomo).

  Normaliza el texto eliminando espacios, convirtiéndolo a minúsculas y
  reemplazando espacios por guiones bajos antes de convertirlo a átomo.

  ## Parámetros
  - `texto`: El string a convertir (ej. `"primeros auxilios"`).

  ## Retorna
  - `{:ok, tipo}` si el texto corresponde a un tipo válido.
  - `{:error, :tipo_invalido}` en caso contrario.

  ## Ejemplos
      iex> Necesidad.parsear_tipo("Agua")
      {:ok, :agua}

      iex> Necesidad.parsear_tipo("primeros auxilios")
      {:ok, :primeros_auxilios}
  """
  def parsear_tipo(texto) when is_binary(texto) do
    tipo =
      texto
      |> String.trim()
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.to_atom()

    if tipo_valido?(tipo), do: {:ok, tipo}, else: {:error, :tipo_invalido}
  end

  @doc """
  Convierte un string en una prioridad válida (átomo).

  Además de normalizar el texto, elimina las tildes de las vocales para
  aceptar entradas como `"crítica"` o `"Crítica"`.

  ## Parámetros
  - `texto`: El string a convertir (ej. `"crítica"`).

  ## Retorna
  - `{:ok, prioridad}` si el texto corresponde a una prioridad válida.
  - `{:error, :prioridad_invalida}` en caso contrario.

  ## Ejemplos
      iex> Necesidad.parsear_prioridad("Crítica")
      {:ok, :critica}
  """
  def parsear_prioridad(texto) when is_binary(texto) do
    prio =
      texto
      |> String.trim()
      |> String.downcase()
      |> String.replace(["á", "é", "í", "ó", "ú"], fn
        "á" -> "a"
        "é" -> "e"
        "í" -> "i"
        "ó" -> "o"
        "ú" -> "u"
      end)
      |> String.to_atom()

    if prioridad_valida?(prio), do: {:ok, prio}, else: {:error, :prioridad_invalida}
  end

  @doc """
  Retorna un número que representa el peso de una prioridad para ordenamiento.

  Se utiliza en el GenServer de Necesidades para ordenar la lista de solicitudes
  de manera que las más urgentes aparezcan primero.

  ## Parámetros
  - `prioridad`: Un átomo (`:critica`, `:alta`, `:media` o `:baja`).

  ## Retorna
  - Un entero: `1` para `:critica`, `2` para `:alta`, `3` para `:media` y `4` para `:baja`.

  ## Ejemplos
      iex> Necesidad.peso_prioridad(:critica)
      1
  """
  def peso_prioridad(:critica), do: 1
  def peso_prioridad(:alta), do: 2
  def peso_prioridad(:media), do: 3
  def peso_prioridad(:baja), do: 4
end
