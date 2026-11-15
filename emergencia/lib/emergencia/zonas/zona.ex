defmodule Emergencia.Zonas.Zona do
  @moduledoc """
  Representa una zona afectada por la emergencia y organiza la información de
  forma jerárquica: Zona → Sector → Punto de atención.

  Este módulo define la estructura de datos de una zona, sus niveles de
  afectación válidos y el algoritmo recursivo que calcula el total estimado de
  personas afectadas.

  Las funciones de este módulo son puras: no modifican el estado global ni
  persisten en disco. El GenServer `Emergencia.Zonas` es quien se encarga de
  registrar, buscar y eliminar zonas, delegando el cálculo recursivo a este módulo.
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
  Devuelve la lista de niveles de afectación válidos.

  Los niveles disponibles son: `:critico`, `:alto`, `:medio` y `:bajo`.
  """
  def niveles, do: @niveles

  @doc """
  Verifica si un nivel de afectación es válido.

  ## Parámetros
  - `nivel`: El nivel a validar (debe ser un átomo).

  ## Retorna
  - `true` si el nivel está en la lista de niveles válidos.
  - `false` en caso contrario (incluyendo si no es un átomo).
  """
  def nivel_valido?(nivel) when is_atom(nivel), do: nivel in @niveles
  def nivel_valido?(_), do: false

  @doc """
  Convierte un string en un nivel de afectación válido (átomo).

  Normaliza el texto eliminando espacios, convirtiéndolo a minúsculas y
  eliminando las tildes de las vocales (por ejemplo, `"Crítico"` se convierte
  en `"critico"`).

  ## Parámetros
  - `texto`: El string a convertir (ej. `"Crítico"`, `"ALTO"`, `"medio"`).

  ## Retorna
  - `{:ok, nivel}` si el texto corresponde a un nivel válido.
  - `{:error, :nivel_invalido}` en caso contrario.

  ## Ejemplos
      iex> Zona.parsear_nivel("Crítico")
      {:ok, :critico}

      iex> Zona.parsear_nivel("desconocido")
      {:error, :nivel_invalido}
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
  Calcula el total de personas afectadas en una zona recorriendo recursivamente
  todos sus sectores y puntos de atención.

  Este es el algoritmo recursivo principal del proyecto. Recorre la estructura
  jerárquica Zona → Sectores → Puntos y suma el campo `personas_afectadas` de
  cada punto.

  ## Parámetros
  - `zona`: El struct `%Zona{}` a evaluar.

  ## Retorna
  - Un número entero con el total de personas afectadas en la zona.

  ## Ejemplos
      iex> punto = %Punto{nombre: "Escuela", personas_afectadas: 50}
      iex> sector = %Sector{nombre: "Centro", puntos: [punto]}
      iex> zona = %Zona{codigo: "Z001", sectores: [sector]}
      iex> Zona.calcular_total_personas(zona)
      50
  """
  def calcular_total_personas(%__MODULE__{sectores: sectores}) do
    contar_personas_en_sectores(sectores)
  end

  # Función auxiliar recursiva para recorrer la lista de sectores.
  # Caso base: una lista vacía suma 0.
  # Caso recursivo: suma las personas de los puntos del sector actual
  # y continúa con el resto de los sectores.
  def contar_personas_en_sectores([]), do: 0

  def contar_personas_en_sectores([sector | resto]) do
    contar_personas_en_puntos(sector.puntos) + contar_personas_en_sectores(resto)
  end

  # Función auxiliar recursiva para recorrer la lista de puntos.
  # Caso base: una lista vacía suma 0.
  # Caso recursivo: suma las personas del punto actual y continúa con el resto.
  defp contar_personas_en_puntos([]), do: 0

  defp contar_personas_en_puntos([punto | resto]) do
    punto.personas_afectadas + contar_personas_en_puntos(resto)
  end
end
