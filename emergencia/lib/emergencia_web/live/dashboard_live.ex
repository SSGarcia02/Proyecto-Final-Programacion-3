defmodule EmergenciaWeb.DashboardLive do
  use EmergenciaWeb, :live_view

  alias Emergencia.{Zonas, Necesidades, Recursos, Albergues, Personas, Mascotas}

  @impl true
  def mount(_params, session, socket) do
    case session do
      %{"username" => username, "tipo" => tipo, "zona" => zona} ->
        # --- RECURSOS CRÍTICOS (menos de 10 unidades) ---
        recursos_criticos =
          Recursos.listar()
          |> Enum.filter(&(&1.cantidad < 10))

        # --- NECESIDADES ---
        todas_necesidades = Necesidades.listar_ordenadas()
        necesidades_pendientes = Enum.count(todas_necesidades, &(&1.estado == "pendiente"))
        necesidades_atendidas = Enum.count(todas_necesidades, &(&1.estado == "atendida"))

        # --- PERSONAS ---
        todas_personas = Personas.listar_personas()

        personas_localizadas =
          Enum.count(todas_personas, &(&1.estado == "localizada" or &1.estado == "reunificada"))

        # --- ALBERGUES ---
        todos_albergues = Albergues.listar()
        total_capacidad = Enum.sum(Enum.map(todos_albergues, & &1.capacidad_maxima))
        total_ocupacion = Enum.sum(Enum.map(todos_albergues, & &1.ocupacion_actual))

        porcentaje_ocupacion =
          if total_capacidad > 0,
            do: total_ocupacion / total_capacidad * 100,
            else: 0.0

        # --- MASCOTAS ---
        todas_mascotas = Mascotas.listar()
        mascotas_activas = Enum.count(todas_mascotas, &(&1.estado == "activa"))

        mascotas_coincidencias =
          Enum.count(todas_mascotas, &(&1.estado == "posible_coincidencia"))

        {:ok,
         socket
         |> assign(:username, username)
         |> assign(:tipo, tipo)
         |> assign(:zona, zona)
         |> assign(:stats, %{
           zonas: length(Zonas.listar()),
           recursos_criticos: recursos_criticos,
           total_recursos: length(Recursos.listar()),
           necesidades_pendientes: necesidades_pendientes,
           necesidades_atendidas: necesidades_atendidas,
           personas_localizadas: personas_localizadas,
           total_personas: length(todas_personas),
           porcentaje_ocupacion: porcentaje_ocupacion,
           total_albergues: length(todos_albergues),
           mascotas_activas: mascotas_activas,
           mascotas_coincidencias: mascotas_coincidencias
         })}

      _ ->
        {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="zonas-container">
      <!-- BARRA SUPERIOR -->
      <div class="dashboard-header">
        <h1>Panel de Comando</h1>
        <div>
          <span style="margin-right: 1rem;">
            Usuario: <strong>{@username}</strong> ({@tipo})
          </span>
          <a href="/logout" style="color: white; text-decoration: underline;">Cerrar Sesión</a>
        </div>
      </div>

      <!-- ALERTA DE RECURSOS CRÍTICOS -->
      <%= if length(@stats.recursos_criticos) > 0 do %>
        <div style="background: #f8d7da; border-left: 4px solid #dc3545; padding: 1rem; margin-bottom: 2rem; border-radius: 4px;">
          <h3 style="margin-top: 0; color: #721c24;">⚠️ Alerta de Recursos Críticos</h3>
          <p style="margin: 0; color: #721c24;">
            Los siguientes recursos tienen menos de 10 unidades:
            <strong>{Enum.map_join(@stats.recursos_criticos, ", ", &"#{&1.nombre} (#{&1.cantidad})")}</strong>
          </p>
        </div>
      <% end %>

      <!-- ESTADÍSTICAS GLOBALES -->
      <h3 style="color: #333;">Resumen Global del Sistema</h3>
      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin-bottom: 2rem;">
        <div style="background: #ffffff; border: 1px solid #ddd; padding: 1rem; border-radius: 8px; text-align: center; border-top: 4px solid #dc3545;">
          <h4 style="margin: 0 0 0.5rem 0; color: #333;">Necesidades</h4>
          <p style="font-size: 2rem; margin: 0; color: #dc3545; font-weight: bold;">
            {@stats.necesidades_pendientes}
          </p>
          <p style="margin: 0; font-size: 0.8rem; color: #666;">Pendientes</p>
          <p style="margin: 0.5rem 0 0 0; font-size: 0.8rem; color: green;">
            {@stats.necesidades_atendidas} Atendidas
          </p>
        </div>

        <div style="background: #ffffff; border: 1px solid #ddd; padding: 1rem; border-radius: 8px; text-align: center; border-top: 4px solid #007bff;">
          <h4 style="margin: 0 0 0.5rem 0; color: #333;">Personas</h4>
          <p style="font-size: 2rem; margin: 0; color: #007bff; font-weight: bold;">
            {@stats.personas_localizadas}
          </p>
          <p style="margin: 0; font-size: 0.8rem; color: #666;">Localizadas/Reunificadas</p>
          <p style="margin: 0.5rem 0 0 0; font-size: 0.8rem; color: #666;">
            de {@stats.total_personas} registradas
          </p>
        </div>

        <div style="background: #ffffff; border: 1px solid #ddd; padding: 1rem; border-radius: 8px; text-align: center; border-top: 4px solid #28a745;">
          <h4 style="margin: 0 0 0.5rem 0; color: #333;">Albergues</h4>
          <p style="font-size: 2rem; margin: 0; color: #28a745; font-weight: bold;">
            {Float.round(@stats.porcentaje_ocupacion, 1)}%
          </p>
          <p style="margin: 0; font-size: 0.8rem; color: #666;">Ocupación Global</p>
          <p style="margin: 0.5rem 0 0 0; font-size: 0.8rem; color: #666;">
            {@stats.total_albergues} Albergues activos
          </p>
        </div>

        <div style="background: #ffffff; border: 1px solid #ddd; padding: 1rem; border-radius: 8px; text-align: center; border-top: 4px solid #ffc107;">
          <h4 style="margin: 0 0 0.5rem 0; color: #333;">Mascotas</h4>
          <p style="font-size: 2rem; margin: 0; color: #ffc107; font-weight: bold;">
            {@stats.mascotas_activas}
          </p>
          <p style="margin: 0; font-size: 0.8rem; color: #666;">Reportes Activos</p>
          <p style="margin: 0.5rem 0 0 0; font-size: 0.8rem; color: #17a2b8;">
            {@stats.mascotas_coincidencias} Posibles Coincidencias
          </p>
        </div>
      </div>

      <h3 style="color: #333; margin-bottom: 1rem;">Acceso a Módulos</h3>

      <div class="dashboard-grid">
        <!-- Zonas: Solo coordinadores y administradores -->
        <%= if @tipo == "coordinador" or @tipo == "administrador" do %>
          <a href="/zonas" class="dashboard-card">
            <h3>Gestión de Zonas</h3>
            <p>Registra sectores, puntos de atención y niveles de afectación.</p>
          </a>
        <% end %>

        <!-- Recursos: Coordinadores, administradores y voluntarios -->
        <%= if @tipo in ["coordinador", "administrador", "voluntario"] do %>
          <a href="/recursos" class="dashboard-card">
            <h3>Inventario de Recursos</h3>
            <p>Controla suministros, entradas y salidas de los centros de acopio.</p>
          </a>
        <% end %>

        <!-- Necesidades: Coordinadores, administradores y voluntarios -->
        <%= if @tipo in ["coordinador", "administrador", "voluntario"] do %>
          <a href="/necesidades" class="dashboard-card">
            <h3>Gestión de Necesidades</h3>
            <p>Administra solicitudes de ayuda y asígnalas a recursos disponibles.</p>
          </a>
        <% end %>

        <!-- Albergues: Coordinadores, administradores y voluntarios -->
        <%= if @tipo in ["coordinador", "administrador", "voluntario"] do %>
          <a href="/albergues" class="dashboard-card">
            <h3>Gestión de Albergues</h3>
            <p>Controla cupos, capacidad máxima y personas alojadas.</p>
          </a>
        <% end %>

        <!-- Personas y Mensajes: TODOS pueden verlo (ciudadanos también) -->
        <a href="/personas" class="dashboard-card">
          <h3>Personas y Mensajes</h3>
          <p>Busca damnificados y permite la comunicación entre familiares.</p>
        </a>

        <!-- Mascotas: TODOS pueden verlo -->
        <a href="/mascotas" class="dashboard-card">
          <h3>Mascotas</h3>
          <p>Reportes de mascotas perdidas y encontradas con algoritmo de coincidencia.</p>
        </a>
      </div>
    </div>
    """
  end
end
