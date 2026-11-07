defmodule Emergencia.Usuarios.Usuario do
  @moduledoc """
  Representa un usuario del sistema de emergencias.
  """
  @enforce_keys [:username, :password, :nombre_completo, :tipo, :zona]
  defstruct [:username, :password, :nombre_completo, :tipo, :zona, conectado: false]

  @tipos [:ciudadano, :voluntario, :coordinador, :administrador]

  @doc """
  Lista de tipos de usuario válidos.
  """
  def tipos, do: @tipos

  @doc """
  Valida que un tipo de usuario sea válido.
  """
  def tipo_valido?(tipo) when is_atom(tipo), do: tipo in @tipos
  def tipo_valido?(_), do: false

  @doc """
  Convierte un string en un tipo de usuario (átomo).
  Devuelve {:ok, tipo} o {:error, :tipo_invalido}.
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
