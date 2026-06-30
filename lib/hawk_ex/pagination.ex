defmodule HawkEx.Pagination do
  @moduledoc """
  Shared offset-based pagination helper, used internally by
  HawkEx.Audit, HawkEx.Billing, and HawkEx.CSV.

  Not part of the public API surface — host applications should use
  the pagination functions on each context (`Audit.recent/1`,
  `Billing.recent_subscriptions/1`, `CSV.recent_exports/1`) rather
  than calling this directly.
  """

  import Ecto.Query

  alias HawkEx.Config

  @doc """
  Paginates a base Ecto query.

  ## Options
    * `:page` — 1-indexed page number (default: 1)
    * `:per_page` — rows per page (default: 50)
    * `:search` — optional search term (default: nil)
    * `:search_fun` — `(query, search_term) -> query`, applied only
      when `:search` is present and non-empty. Required if `:search`
      may be passed.
    * `:order_by` — keyword list passed straight to Ecto's `order_by`
      (default: `[desc: :inserted_at]`)
    * `:preload` — passed straight to Ecto's `preload` (default: `[]`)

  Returns `%{entries:, page:, per_page:, total_count:, total_pages:}`.
  """
  def paginate(base_query, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 50)
    search = Keyword.get(opts, :search)
    search_fun = Keyword.get(opts, :search_fun)
    order_by = Keyword.get(opts, :order_by, desc: :inserted_at)
    preload = Keyword.get(opts, :preload, [])
    offset_val = (page - 1) * per_page

    filtered = apply_search(base_query, search, search_fun)

    total_count = Config.repo().aggregate(filtered, :count, :id)

    entries =
      filtered
      |> order_by(^order_by)
      |> limit(^per_page)
      |> offset(^offset_val)
      |> preload(^preload)
      |> Config.repo().all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: max(1, ceil(total_count / per_page))
    }
  end

  defp apply_search(query, search, _fun) when search in [nil, ""], do: query
  defp apply_search(query, search, fun) when is_function(fun, 2), do: fun.(query, search)

  defp apply_search(_query, _search, nil) do
    raise ArgumentError, "search term given but no :search_fun was provided"
  end
end
