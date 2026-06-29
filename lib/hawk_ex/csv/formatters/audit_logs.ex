defmodule HawkEx.CSV.Formatters.AuditLogs do
  @behaviour HawkEx.CSV.Formatter

  import Ecto.Query
  alias HawkEx.Audit.Log

  @impl true
  def headers do
    ["id", "actor_id", "actor_type", "action", "resource_id", "resource_type", "inserted_at"]
  end

  @impl true
  def to_row(%Log{} = log) do
    [
      log.id,
      log.actor_id || "",
      log.actor_type || "",
      log.action,
      log.resource_id || "",
      log.resource_type || "",
      DateTime.to_iso8601(log.inserted_at)
    ]
  end

  @impl true
  def query(account_id) do
    from(l in Log,
      where: l.resource_id == ^account_id,
      order_by: [desc: l.inserted_at]
    )
  end
end
