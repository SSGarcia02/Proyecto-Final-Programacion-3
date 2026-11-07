defmodule EmergenciaWeb.DashboardLive do
  use EmergenciaWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    # session contiene lo que guardamos con put_session en el controlador
    case session do
      %{"username" => username, "tipo" => tipo, "zona" => zona} ->
        {:ok,
         socket
         |> assign(:username, username)
         |> assign(:tipo, tipo)
         |> assign(:zona, zona)}

      _ ->
        # Si no hay sesión, redirigimos al login
        {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dashboard-container">
      <header>
        <h1>Panel de Emergencias</h1>
        
        <div class="user-info">
          <p>Conectado como: <strong>{@username}</strong> ({@tipo}) - Zona: {@zona}</p>
          
          <a href="/logout" class="btn-logout" data-confirm="¿Seguro que deseas salir?">Cerrar Sesión</a>
        </div>
      </header>
      
      <main>
        <h2>Bienvenido al sistema</h2>
        
        <p>Desde aquí podrás gestionar zonas, necesidades, recursos, albergues y reportes.</p>
        
        <p><em>(Los módulos de gestión se agregarán en las siguientes fases)</em></p>
      </main>
    </div>
    """
  end
end
