defmodule HawkEx.Audit do
  @moduledoc """
  Records and queries audit log entries.

  ## Automatic recording

  HAWK_EX automatically records audit entries for all internal
  billing events when PubSub is configured. No setup required.

  ## Manual recording

  Use `track/3` to record your own application events:

      HawkEx.Audit.track(
        current_user,
        "project.deleted",
        project
      )

  ## Querying

      HawkEx.Audit.recent(limit: 50)
      HawkEx.Audit.for_account(account_id)
  """

  import Ecto.Query

  alias HawkEx.Config
  alias HawkEx.Audit.Log

  # --- Public API-----------------------------------------------------------

  @doc """
  Manually records an audit entry.

  Actor can be any struct with an :id field, or nil for system actions.
  Resource can be any struct with an :id field, or nil.

  ## Example

      HawkEx.Audit.track(current_user, "settings.updated", organization)
  """
  def track(actor, action, resource \\ nil) when is_binary(action) do
    %Log{}
    |> Log.changeset(%{
      actor_id: extract_id(actor),
      actor_type: extract_type(actor),
      action: action,
      resource_id: extract_id(resource),
      resource_type: extract_type(resource),
      metadata: %{}
    })
    |> Config.repo().insert()
  end

  @doc """
  Returns a page of audit log entries, newest first.

  ## Options
    * `:page` — 1-indexed page number (default: 1)
    * `:per_page` — rows per page (default: 50)
    * `:search` — optional search term to filter by action (default: nil)

  Returns a map with the page of entries plus pagination metadata,
  so the caller never needs a second query to know total pages.

  ## Example

      HawkEx.Audit.recent(page: 1, per_page: 50)
      # => %{entries: [...], page: 1, per_page: 50, total_count: 312, total_pages: 7}
  """
  def recent(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 50)
    search = Keyword.get(opts, :search)
    offset = (page - 1) * per_page

    filtered = filter_query(search)

    total_count =
      Config.repo().aggregate(filtered, :count, :id)

    entries =
      Config.repo().all(
        from(l in filtered,
          order_by: [desc: l.inserted_at],
          limit: ^per_page,
          offset: ^offset
        )
      )

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: ceil(total_count / per_page)
    }
  end

  @doc "Returns all audit entries for a specific account_id."
  def for_account(account_id) do
    Config.repo().all(
      from(l in Log,
        where: l.resource_id == ^account_id,
        order_by: [desc: l.inserted_at]
      )
    )
  end

  # ---Internal-------------------------------------------------------------

  @doc false
  def record_from_event(event_name, payload) do
    %Log{}
    |> Log.changeset(%{
      action: event_name,
      resource_id: Map.get(payload, :account_id),
      resource_type: "account",
      metadata: payload
    })
    |> Config.repo().insert()
  end

  # ---Private-------------------------------------------------------------

  defp filter_query(search) when search in [nil, ""], do: from(l in Log)

  defp filter_query(search) do
    pattern = "%#{search}%"
    from(l in Log, where: ilike(l.action, ^pattern))
  end

  defp extract_id(nil), do: nil
  defp extract_id(%{id: id}), do: id

  defp extract_type(nil), do: nil
  defp extract_type(%mod{}), do: mod |> to_string() |> String.replace("Elixir.", "")
end
