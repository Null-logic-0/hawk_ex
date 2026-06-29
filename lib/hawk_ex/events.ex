defmodule HawkEx.Events do
  @moduledoc """
  Broadcasts business events through the host application's PubSub.

  Events are only broadcast when `config :hawk_ex, pubsub:` is set.
  Without it, `emit/2` is a silent no-op — the library works without
  PubSub configured.

  ## Topic

  All events are broadcast on a single topic: `"hawk_ex:events"`.

  ## Subscribing

      HawkEx.Events.subscribe()

      # Then handle in a GenServer or LiveView:
      def handle_info({HawkEx.Events, event, payload}, state) do
        ...
      end

  ## Event names

  String dot-notation:

      "subscription.created"
      "subscription.canceled"
      "subscription.plan_changed"

  ## Payload

  Each event carries a map with at minimum:

      %{account_id: uuid, ...event-specific fields}
  """

  alias HawkEx.Config

  @topic "hawk_ex:events"

  @doc "Broadcasts an event to all subscribers."
  def emit(event_name, payload) when is_binary(event_name) and is_map(payload) do
    case Config.pubsub() do
      nil ->
        :ok

      pubsub ->
        Phoenix.PubSub.broadcast(pubsub, @topic, {__MODULE__, event_name, payload})
    end
  end

  @doc "Subscribes the calling process to all HAWK_EX events."
  def subscribe do
    case Config.pubsub() do
      nil -> :ok
      pubsub -> Phoenix.PubSub.subscribe(pubsub, @topic)
    end
  end

  @doc "The PubSub topic all events are broadcast on."
  def topic, do: @topic
end
