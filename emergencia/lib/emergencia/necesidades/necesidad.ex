defmodule Emergencia.Necesidades.Necesidad do
  @moduledoc """
  Representa una solicitud de ayuda en una zona afectada.
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

  def tipos, do: @tipos
  def prioridades, do: @prioridades
  def estados, do: @estados

  def tipo_valido?(tipo) when is_atom(tipo), do: tipo in @tipos
  def tipo_valido?(_), do: false

  def prioridad_valida?(prio) when is_atom(prio), do: prio in @prioridades
  def prioridad_valida?(_), do: false

  def estado_valido?(estado) when is_binary(estado), do: estado in @estados
  def estado_valido?(_), do: false

  def parsear_tipo(texto) when is_binary(texto) do
    tipo =
      texto
      |> String.trim()
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.to_atom()

    if tipo_valido?(tipo), do: {:ok, tipo}, else: {:error, :tipo_invalido}
  end

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
  Retorna un número para ordenar las prioridades (crítica = 1, baja = 4).
  """
  def peso_prioridad(:critica), do: 1
  def peso_prioridad(:alta), do: 2
  def peso_prioridad(:media), do: 3
  def peso_prioridad(:baja), do: 4
end
