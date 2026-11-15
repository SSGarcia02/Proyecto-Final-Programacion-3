defmodule Emergencia.FuncionesPurasTest do
  use ExUnit.Case, async: true

  alias Emergencia.Zonas.{Zona, Sector, Punto}
  alias Emergencia.Mascotas.Mascota
  alias Emergencia.Recursos.Recurso
  alias Emergencia.Albergues.Albergue

  describe "Recursividad en Zonas" do
    test "calcular_total_personas/1 suma las personas de todos los sectores y puntos" do
      # Creamos una zona con 2 sectores, cada uno con 2 puntos
      puntos1 = [
        %Punto{nombre: "Escuela", personas_afectadas: 50},
        %Punto{nombre: "Parque", personas_afectadas: 30}
      ]

      puntos2 = [
        %Punto{nombre: "Hospital", personas_afectadas: 100},
        %Punto{nombre: "Puente", personas_afectadas: 20}
      ]

      sectores = [
        %Sector{nombre: "Centro", puntos: puntos1},
        %Sector{nombre: "Norte", puntos: puntos2}
      ]

      zona = %Zona{codigo: "Z001", nombre: "Zona 1", nivel: :critico, sectores: sectores}

      # Suma total: 50 + 30 + 100 + 20 = 200
      assert Zona.calcular_total_personas(zona) == 200
    end

    test "calcular_total_personas/1 retorna 0 si no hay sectores" do
      zona = %Zona{codigo: "Z002", nombre: "Zona Vacia", nivel: :bajo, sectores: []}
      assert Zona.calcular_total_personas(zona) == 0
    end

    test "calcular_total_personas/1 retorna 0 si no hay puntos en los sectores" do
      sector = %Sector{nombre: "Centro", puntos: []}
      zona = %Zona{codigo: "Z003", nombre: "Zona Sin Puntos", nivel: :medio, sectores: [sector]}
      assert Zona.calcular_total_personas(zona) == 0
    end
  end

  describe "Algoritmo de coincidencia de Mascotas" do
    test "calcular_coincidencia/2 retorna puntaje alto para reportes similares" do
      perdida = %Mascota{
        id: "M1",
        tipo_reporte: "perdida",
        especie: "perro",
        zona: "Z001",
        color: "negro",
        tamano: "mediano",
        contacto: "123"
      }

      encontrada = %Mascota{
        id: "M2",
        tipo_reporte: "encontrada",
        especie: "perro",
        zona: "Z001",
        color: "negro",
        tamano: "mediano",
        contacto: "456"
      }

      # Especie (30) + Zona (30) + Color (20) + Tamaño (20) = 100
      assert Mascota.calcular_coincidencia(perdida, encontrada) == 100
    end

    test "calcular_coincidencia/2 retorna 0 si son del mismo tipo" do
      m1 = %Mascota{
        id: "M1",
        tipo_reporte: "perdida",
        especie: "perro",
        zona: "Z001",
        contacto: "123"
      }

      m2 = %Mascota{
        id: "M2",
        tipo_reporte: "perdida",
        especie: "perro",
        zona: "Z001",
        contacto: "456"
      }

      assert Mascota.calcular_coincidencia(m1, m2) == 0
    end

    test "calcular_coincidencia/2 retorna puntaje parcial si solo coincide la especie" do
      perdida = %Mascota{
        id: "M1",
        tipo_reporte: "perdida",
        especie: "perro",
        zona: "Z001",
        color: "negro",
        tamano: "mediano",
        contacto: "123"
      }

      encontrada = %Mascota{
        id: "M2",
        tipo_reporte: "encontrada",
        especie: "perro",
        zona: "Z002",
        color: "blanco",
        tamano: "grande",
        contacto: "456"
      }

      # Solo especie (30)
      assert Mascota.calcular_coincidencia(perdida, encontrada) == 30
    end
  end

  describe "Validaciones de Recursos" do
    test "ingresar/2 suma cantidad y agrega al historial" do
      recurso = %Recurso{
        codigo: "R1",
        nombre: "Agua",
        categoria: :agua,
        unidad: "L",
        ubicacion: "C1",
        cantidad: 10,
        historial: []
      }

      {:ok, actualizado} = Recurso.ingresar(recurso, 5)

      assert actualizado.cantidad == 15
      assert length(actualizado.historial) == 1
      assert hd(actualizado.historial).tipo == "entrada"
      assert hd(actualizado.historial).cantidad == 5
    end

    test "egresar/2 resta cantidad si hay suficiente" do
      recurso = %Recurso{
        codigo: "R1",
        nombre: "Agua",
        categoria: :agua,
        unidad: "L",
        ubicacion: "C1",
        cantidad: 10,
        historial: []
      }

      {:ok, actualizado} = Recurso.egresar(recurso, 3)

      assert actualizado.cantidad == 7
      assert hd(actualizado.historial).tipo == "salida"
    end

    test "egresar/2 retorna error si no hay suficiente cantidad" do
      recurso = %Recurso{
        codigo: "R1",
        nombre: "Agua",
        categoria: :agua,
        unidad: "L",
        ubicacion: "C1",
        cantidad: 10,
        historial: []
      }

      assert {:error, :sin_existencias} = Recurso.egresar(recurso, 15)
    end

    test "ingresar/2 retorna error con cantidad negativa" do
      recurso = %Recurso{
        codigo: "R1",
        nombre: "Agua",
        categoria: :agua,
        unidad: "L",
        ubicacion: "C1",
        cantidad: 10,
        historial: []
      }

      assert {:error, :cantidad_invalida} = Recurso.ingresar(recurso, -5)
    end
  end

  describe "Validaciones de Albergues" do
    test "ingresar/2 incrementa ocupación si hay cupo" do
      albergue = %Albergue{
        codigo: "A1",
        nombre: "Norte",
        zona: "Z1",
        capacidad_maxima: 5,
        ocupacion_actual: 0,
        personas: []
      }

      {:ok, actualizado} = Albergue.ingresar(albergue, "12345")

      assert actualizado.ocupacion_actual == 1
      assert "12345" in actualizado.personas
    end

    test "ingresar/2 retorna error si no hay cupo" do
      albergue = %Albergue{
        codigo: "A1",
        nombre: "Norte",
        zona: "Z1",
        capacidad_maxima: 1,
        ocupacion_actual: 1,
        personas: ["123"]
      }

      assert {:error, :sin_cupo} = Albergue.ingresar(albergue, "456")
    end

    test "ingresar/2 retorna error si la persona ya está en el albergue" do
      albergue = %Albergue{
        codigo: "A1",
        nombre: "Norte",
        zona: "Z1",
        capacidad_maxima: 5,
        ocupacion_actual: 1,
        personas: ["123"]
      }

      assert {:error, :ya_esta_en_albergue} = Albergue.ingresar(albergue, "123")
    end
  end
end
