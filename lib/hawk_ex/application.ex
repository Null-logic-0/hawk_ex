defmodule HawkEx.Application do
  use Application

  @moduledoc false

  def start(_type, _args) do
    children = [
      HawkEx.Audit.Listener
    ]

    opts = [strategy: :one_for_one, name: HawkEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
