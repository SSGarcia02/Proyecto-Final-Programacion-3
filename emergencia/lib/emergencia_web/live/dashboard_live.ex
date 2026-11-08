defmodule EmergenciaWeb.DashboardLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.{Zonas, Necesidades, Recursos, Albergues, Personas}

  @impl true
  def mount(_params, session, socket) do
    case session do
      %{"username" => username, "tipo" => tipo, "zona" => zona} ->
        # Obtenemos estadísticas rápidas de todo el sistema
        {:ok,
         socket
         |> assign(:username, username)
         |> assign(:tipo, tipo)
         |> assign(:zona, zona)
         |> assign(:stats, %{
           zonas: length(Zonas.listar()),
           necesidades: length(Necesidades.listar_ordenadas()),
           recursos: length(Recursos.listar()),
           albergues: length(Albergues.listar()),
           personas: length(Personas.listar_personas())
         })}

      _ ->
        {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <!-- BARRA SUPERIOR CORREGIDA -->
      <div class="dashboard-header">
        <h1>Panel de Emergencias</h1>
        <div>
          <span style="margin-right: 1rem;">
            Conectado como: <strong><%= @username %></strong> (<%= @tipo %>)
          </span>
          <a href="/logout" style="color: white; text-decoration: underline;">Cerrar Sesión</a>
        </div>
      </div>

      <!-- CONTENIDO -->
      <div style="background: #e9ecef; padding: 1rem; border-radius: 8px; border-left: 4px solid #007bff; margin-bottom: 2rem;">
        <h2 style="margin-top: 0; color: #333;">Bienvenido al Sistema de Emergencias</h2>
        <p style="margin: 0; color: #555;">
          Estado actual:
          <strong><%= @stats.zonas %></strong> Zonas |
          <strong><%= @stats.necesidades %></strong> Necesidades |
          <strong><%= @stats.recursos %></strong> Recursos en Inventario |
          <strong><%= @stats.albergues %></strong> Albergues |
          <strong><%= @stats.personas %></strong> Personas Registradas
        </p>
      </div>

      <h3 style="color: #333; margin-bottom: 1rem;">Módulos del Sistema</h3>

      <div class="dashboard-grid">
        <a href="/zonas" class="dashboard-card">
          <h3>Gestión de Zonas</h3>
          <p>Registra sectores, puntos de atención y niveles de afectación.</p>
        </a>

        <a href="/recursos" class="dashboard-card">
          <h3>Inventario de Recursos</h3>
          <p>Controla suministros, entradas y salidas de los centros de acopio.</p>
        </a>

        <a href="/necesidades" class="dashboard-card">
          <h3>Gestión de Necesidades</h3>
          <p>Administra solicitudes de ayuda y asígnalas a recursos disponibles.</p>
        </a>

        <a href="/albergues" class="dashboard-card">
          <h3>Gestión de Albergues</h3>
          <p>Controla cupos, capacidad máxima y personas alojadas.</p>
        </a>

        <a href="/personas" class="dashboard-card">
          <h3>Personas y Mensajes</h3>
          <p>Busca damnificados y permite la comunicación entre familiares.</p>
        </a>

        <!-- Espacio para el módulo de Mascotas (Fase 7) -->
        <div class="dashboard-card" style="background: #eee; cursor: not-allowed; opacity: 0.7;">
          <h3 style="color: #888 !important;">Mascotas (Próximamente)</h3>
          <p>Registro de mascotas perdidas y encontradas.</p>
        </div>
      </div>
    </div>
    """
  end
end
