defmodule HawkEx.Audit.Listener do
  use GenServer

  @moduledoc false

  alias HawkEx.{Audit, Events}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Events.subscribe()
    {:ok, %{}}
  end

  @impl true
  def handle_info({Events, event_name, payload}, state) do
    Audit.record_from_event(event_name, payload)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
