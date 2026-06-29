defmodule HawkEx.CSV.Formatters.Subscriptions do
  @behaviour HawkEx.CSV.Formatter

  import Ecto.Query
  alias HawkEx.Billing.Subscription

  @impl true
  def headers do
    [
      "id",
      "account_id",
      "plan",
      "status",
      "trial_ends_at",
      "current_period_start",
      "current_period_end",
      "canceled_at",
      "inserted_at"
    ]
  end

  @impl true
  def to_row(%Subscription{} = sub) do
    [
      sub.id,
      sub.account_id,
      sub.plan.name,
      sub.status,
      format_dt(sub.trial_ends_at),
      format_dt(sub.current_period_start),
      format_dt(sub.current_period_end),
      format_dt(sub.canceled_at),
      format_dt(sub.inserted_at)
    ]
  end

  @impl true
  def query(account_id) do
    from(s in Subscription,
      where: s.account_id == ^account_id,
      order_by: [desc: s.inserted_at],
      preload: [:plan]
    )
  end

  defp format_dt(nil), do: ""
  defp format_dt(dt), do: DateTime.to_iso8601(dt)
end
