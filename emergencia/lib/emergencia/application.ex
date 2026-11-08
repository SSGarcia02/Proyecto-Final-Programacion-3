defmodule Emergencia.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EmergenciaWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:emergencia, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Emergencia.PubSub},
      {Finch, name: Emergencia.Finch},
      Emergencia.Usuarios,
      Emergencia.Zonas,
      Emergencia.Recursos,
      Emergencia.Necesidades,
      # Start a worker by calling: Emergencia.Worker.start_link(arg)
      # {Emergencia.Worker, arg},
      # Start to serve requests, typically the last entry
      EmergenciaWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Emergencia.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EmergenciaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
