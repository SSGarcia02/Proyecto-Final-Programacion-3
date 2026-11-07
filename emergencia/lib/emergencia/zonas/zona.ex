defmodule Emergencia.Zonas.Zona do
  @moduledoc """
  Representa una zona afectada por la emergencia.
  Contiene sectores, y cada sector contiene puntos de atención.
  """
  @enforce_keys [:codigo, :nombre, :nivel]
  defstruct [
    :codigo,
    :nombre,
    :nivel,
    personas_afectadas: 0,
    sectores: []
  ]

  @niveles [:critico, :alto, :medio, :bajo]

  @doc """
  Lista de niveles de afectación válidos.
  """
  def niveles, do: @niveles

  @doc """
  Valida que un nivel de afectación sea válido.
  """
  def nivel_valido?(nivel) when is_atom(nivel), do: nivel in @niveles
  def nivel_valido?(_), do: false

  @doc """
  Convierte un string en un nivel de afectación.
  Ignora mayúsculas y tildes (ej. "Crítico" -> :critico).
  """
  def parsear_nivel(texto) when is_binary(texto) do
    # Mapa de reemplazo para tildes
    reemplazos = %{
      "á" => "a",
      "é" => "e",
      "í" => "i",
      "ó" => "o",
      "ú" => "u",
      "Á" => "A",
      "É" => "E",
      "Í" => "I",
      "Ó" => "O",
      "Ú" => "U"
    }

    texto_normalizado =
      texto
      |> String.trim()
      |> String.downcase()
      |> String.replace(Map.keys(reemplazos), fn match -> Map.get(reemplazos, match) end)

    nivel = String.to_atom(texto_normalizado)

    if nivel_valido?(nivel) do
      {:ok, nivel}
    else
      {:error, :nivel_invalido}
    end
  end

  @doc """
  Calcula el total de personas afectadas recorriendo recursivamente
  todos los sectores y puntos de la zona.
  """
  def calcular_total_personas(%__MODULE__{sectores: sectores}) do
    contar_personas_en_sectores(sectores)
  end

  # Función auxiliar recursiva para recorrer la lista de sectores

  def contar_personas_en_sectores([]), do: 0

  def contar_personas_en_sectores([sector | resto]) do
    contar_personas_en_puntos(sector.puntos) + contar_personas_en_sectores(resto)
  end

  # Función auxiliar recursiva para recorrer la lista de puntos
  defp contar_personas_en_puntos([]), do: 0

  defp contar_personas_en_puntos([punto | resto]) do
    punto.personas_afectadas + contar_personas_en_puntos(resto)
  end
end
