defmodule Emergencia.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc """
  Punto de entrada y Supervisor principal de la aplicación.

  Este módulo define el árbol de supervisión OTP. Su función `start/2` es
  invocada automáticamente por la máquina virtual de Erlang (BEAM) cuando la
  aplicación arranca. Se encarga de iniciar todos los procesos hijos (servicios
  de Phoenix, GenServers de dominio y el Endpoint) bajo un Supervisor con
  estrategia `:one_for_one`.

  La estrategia `:one_for_one` significa que si un proceso hijo falla, solo ese
  proceso se reinicia, dejando intactos los demás. Esto garantiza la tolerancia
  a fallos del sistema.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # --- Servicios base de Phoenix ---
      EmergenciaWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:emergencia, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Emergencia.PubSub},
      {Finch, name: Emergencia.Finch},

      # --- GenServers de Dominio (Backend) ---
      # Cada uno mantiene el estado en memoria de su módulo y lo persiste en CSV.
      Emergencia.Usuarios,
      Emergencia.Zonas,
      Emergencia.Recursos,
      Emergencia.Necesidades,
      Emergencia.Albergues,
      Emergencia.Personas,
      Emergencia.Mascotas,

      # --- Servidor Web (Frontend) ---
      # Debe ir al final porque depende de que todos los servicios anteriores
      # estén disponibles.
      EmergenciaWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Emergencia.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Notifica al Endpoint de Phoenix que la configuración ha cambiado (por ejemplo,
  en recarga en caliente). No se modifica el código del Endpoint, solo se delega
  el cambio.
  """
  @impl true
  def config_change(changed, _new, removed) do
    EmergenciaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
