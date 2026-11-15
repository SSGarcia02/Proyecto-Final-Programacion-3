defmodule Emergencia.Usuarios.Usuario do
  @moduledoc """
  Representa a un usuario registrado en el sistema de emergencias.

  Este módulo define la estructura de datos de un usuario y las validaciones
  asociadas a su tipo (rol). Los usuarios se identifican por su `username` y
  tienen un `tipo` que determina qué operaciones pueden realizar en el sistema
  (por ejemplo, un coordinador puede gestionar zonas, mientras que un ciudadano
  solo puede consultar personas y mascotas).

  Los tipos de usuario válidos son: `:ciudadano`, `:voluntario`,
  `:coordinador` y `:administrador`.
  """

  @enforce_keys [:username, :password, :nombre_completo, :tipo, :zona]
  defstruct [:username, :password, :nombre_completo, :tipo, :zona, conectado: false]

  @tipos [:ciudadano, :voluntario, :coordinador, :administrador]

  @doc """
  Devuelve la lista de tipos de usuario válidos.

  Los roles disponibles son: `:ciudadano`, `:voluntario`, `:coordinador` y
  `:administrador`.
  """
  def tipos, do: @tipos

  @doc """
  Verifica si un tipo de usuario es válido.

  ## Parámetros
  - `tipo`: El tipo a validar (debe ser un átomo).

  ## Retorna
  - `true` si el tipo está en la lista de tipos válidos.
  - `false` en caso contrario (incluyendo si no es un átomo).

  ## Ejemplos
      iex> Usuario.tipo_valido?(:coordinador)
      true

      iex> Usuario.tipo_valido?(:superadmin)
      false
  """
  def tipo_valido?(tipo) when is_atom(tipo), do: tipo in @tipos
  def tipo_valido?(_), do: false

  @doc """
  Convierte un string en un tipo de usuario válido (átomo).

  Normaliza el texto eliminando espacios y convirtiéndolo a minúsculas antes
  de convertirlo a átomo.

  ## Parámetros
  - `texto`: El string a convertir (ej. `"Coordinador"`).

  ## Retorna
  - `{:ok, tipo}` si el texto corresponde a un tipo válido.
  - `{:error, :tipo_invalido}` en caso contrario.

  ## Ejemplos
      iex> Usuario.parsear_tipo("Coordinador")
      {:ok, :coordinador}

      iex> Usuario.parsear_tipo("hacker")
      {:error, :tipo_invalido}
  """
  def parsear_tipo(texto) when is_binary(texto) do
    tipo =
      texto
      |> String.trim()
      |> String.downcase()
      |> String.to_atom()

    if tipo_valido?(tipo) do
      {:ok, tipo}
    else
      {:error, :tipo_invalido}
    end
  end
end
