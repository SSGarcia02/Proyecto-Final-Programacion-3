defmodule Emergencia.ConcurrenciaTest do
  # No es async para evitar conflictos con GenServers
  use ExUnit.Case, async: false
  alias Emergencia.Recursos
  alias Emergencia.Recursos.Recurso

  setup do
    # Iniciamos el GenServer de Recursos para cada test
    {:ok, _pid} = Recursos.start_link()

    # Registramos un recurso con 10 unidades
    agua = %Recurso{
      codigo: "R_TEST",
      nombre: "Agua de Prueba",
      categoria: :agua,
      unidad: "L",
      ubicacion: "C1",
      cantidad: 10
    }

    {:ok, _} = Recursos.registrar(agua)

    :ok
  end

  test "concurrencia: 5 tareas piden 3 unidades de un total de 10" do
    # Lanzamos 5 tareas en paralelo que piden 3 unidades cada una
    tareas =
      1..5
      |> Enum.map(fn _ ->
        Task.async(fn -> Recursos.egresar("R_TEST", 3) end)
      end)

    # Esperamos los resultados
    resultados = Enum.map(tareas, &Task.await/1)

    # Deberíamos tener exactamente 3 éxitos y 2 errores
    exitos = Enum.count(resultados, fn r -> match?({:ok, _}, r) end)
    errores = Enum.count(resultados, fn r -> match?({:error, :sin_existencias}, r) end)

    assert exitos == 3
    assert errores == 2

    # Verificamos que el recurso quedó con 1 unidad (10 - 3*3)
    {:ok, recurso_final} = Recursos.buscar("R_TEST")
    assert recurso_final.cantidad == 1
  end

  test "concurrencia: 2 tareas piden 6 unidades de un total de 10" do
    # Lanzamos 2 tareas que piden 6 cada una (total 12 > 10)
    tareas =
      1..2
      |> Enum.map(fn _ ->
        Task.async(fn -> Recursos.egresar("R_TEST", 6) end)
      end)

    resultados = Enum.map(tareas, &Task.await/1)

    # Deberíamos tener exactamente 1 éxito y 1 error
    exitos = Enum.count(resultados, fn r -> match?({:ok, _}, r) end)
    errores = Enum.count(resultados, fn r -> match?({:error, :sin_existencias}, r) end)

    assert exitos == 1
    assert errores == 1

    # El recurso debe quedar con 4 unidades (10 - 6)
    {:ok, recurso_final} = Recursos.buscar("R_TEST")
    assert recurso_final.cantidad == 4
  end
end
