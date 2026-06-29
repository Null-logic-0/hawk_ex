defmodule HawkEx.Audit.Listener do
  use GenServer

  @moduledoc false

  alias HawkEx.{Audit, Events}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    send(self(), :subscribe)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:subscribe, state) do
    case safe_subscribe() do
      :ok ->
        {:noreply, state}

      :error ->
        Process.send_after(self(), :subscribe, 500)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({Events, event_name, payload}, state) do
    Audit.record_from_event(event_name, payload)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp safe_subscribe do
    try do
      Events.subscribe()
      :ok
    rescue
      _ -> :error
    end
  end
end
