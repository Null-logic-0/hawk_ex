defmodule HawkEx.Billing do
  @moduledoc """
  The Billing context. Public API for plan and subscription management.

  ## Examples

      HawkEx.Billing.subscribe(account, :pro)
      HawkEx.Billing.current_subscription(account)
      HawkEx.Billing.cancel(account)
      HawkEx.Billing.change_plan(account, :enterprise)

  All functions accept either an account struct (any Ecto schema with
  an `:id` field) or a raw UUID binary.
  """

  import Ecto.Query

  alias HawkEx.Config
  alias HawkEx.Events
  alias HawkEx.Billing.{Plan, Subscription}

  # ---Public API---------------------------------------------------

  @doc """
  Creates a subscription for an account on the given plan.

  If the plan has `trial_days > 0`, the subscription starts in
  `trialing` status. Otherwise it starts as `active` immediately.

  Returns `{:error, :active_subscription_exists}` if the account
  already has a trialing or active subscription.
  """
  def subscribe(account, plan_name) do
    account_id = extract_account_id(account)
    plan_slug = to_string(plan_name)

    with {:ok, plan} <- fetch_plan(plan_slug),
         :ok <- check_no_active_subscription(account_id),
         {:ok, subscription} <- create_subscription(account_id, plan) do
      Events.emit("subscription.created", %{
        account_id: account_id,
        subscription_id: subscription.id,
        plan_name: plan.name,
        status: subscription.status
      })

      {:ok, subscription}
    end
  end

  @doc """
  Returns the current active or trialing subscription for an account,
  with the plan preloaded. Returns nil if no active subscription.
  """
  def current_subscription(account) do
    account_id = extract_account_id(account)

    Config.repo().one(
      from(s in Subscription,
        where: s.account_id == ^account_id,
        where: s.status in ^Subscription.active_statuses(),
        preload: [:plan]
      )
    )
  end

  @doc """
  Returns the current plan for an account, or nil.
  """
  def current_plan(account) do
    case current_subscription(account) do
      %Subscription{plan: plan} -> plan
      nil -> nil
    end
  end

  @doc """
  Returns a page of active/trialing subscriptions, newest first,
  with plan preloaded.

  ## Options
    * `:page` — 1-indexed page number (default: 1)
    * `:per_page` — rows per page (default: 50)
    * `:search` — optional search term, matches account_id (default: nil)

  Returns a map with the page of entries plus pagination metadata.
  """

  def recent_subscriptions(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 50)
    search = Keyword.get(opts, :search)
    offset = (page - 1) * per_page

    base_query =
      from(s in Subscription,
        where: s.status in ^Subscription.active_statuses()
      )

    filtered = filter_subscriptions(base_query, search)

    total_count = Config.repo().aggregate(filtered, :count, :id)

    entries =
      Config.repo().all(
        from(s in filtered,
          order_by: [desc: s.inserted_at],
          limit: ^per_page,
          offset: ^offset,
          preload: [:plan]
        )
      )

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: max(1, ceil(total_count / per_page))
    }
  end

  @doc """
  Cancels the account's active subscription immediately.

  The subscription record is kept with status `canceled` — subscriptions
  are never deleted. Returns `{:error, :no_active_subscription}` if the
  account has no active or trialing subscription.
  """
  def cancel(account) do
    account_id = extract_account_id(account)

    with {:ok, subscription} <- get_active_subscription(account_id),
         {:ok, canceled} <-
           subscription
           |> Subscription.changeset(%{status: "canceled", canceled_at: utc_now()})
           |> Config.repo().update() do
      Events.emit("subscription.canceled", %{
        account_id: account_id,
        subscription_id: canceled.id,
        canceled_at: canceled.canceled_at
      })

      {:ok, canceled}
    end
  end

  @doc """
  Changes an account's current plan in place.

  Does not cancel and recreate — updates the plan_id on the existing
  subscription. This is intentional for v0.1 simplicity.

  NOTE: A future version should cancel the current subscription and
  create a new one to preserve billing period history. Use Ecto.Multi
  for that transition to keep it atomic.

  Returns `{:error, :no_active_subscription}` if the account has no
  active subscription to change.
  """
  def change_plan(account, new_plan_name) do
    account_id = extract_account_id(account)
    plan_slug = to_string(new_plan_name)

    with {:ok, plan} <- fetch_plan(plan_slug),
         {:ok, subscription} <- get_active_subscription(account_id),
         {:ok, updated} <-
           subscription
           |> Subscription.changeset(%{plan_id: plan.id})
           |> Config.repo().update() do
      Events.emit("subscription.plan_changed", %{
        account_id: account_id,
        subscription_id: updated.id,
        new_plan_name: plan.name
      })

      {:ok, updated}
    end
  end

  # ---Private helpers---------------------------------------------------------

  defp extract_account_id(%{id: id}), do: id

  defp extract_account_id(id) when is_binary(id), do: id

  defp filter_subscriptions(query, search) when search in [nil, ""], do: query

  defp filter_subscriptions(query, search) do
    pattern = "%#{search}%"
    from(s in query, where: ilike(fragment("?::text", s.account_id), ^pattern))
  end

  defp fetch_plan(slug) do
    case Config.repo().get_by(Plan, name: slug, status: "active") do
      nil -> {:error, :plan_not_found}
      plan -> {:ok, plan}
    end
  end

  defp check_no_active_subscription(account_id) do
    exists =
      Config.repo().exists?(
        from(s in Subscription,
          where: s.account_id == ^account_id,
          where: s.status in ^Subscription.active_statuses()
        )
      )

    if exists, do: {:error, :active_subscription_exists}, else: :ok
  end

  defp get_active_subscription(account_id) do
    case Config.repo().one(
           from(s in Subscription,
             where: s.account_id == ^account_id,
             where: s.status in ^Subscription.active_statuses()
           )
         ) do
      nil -> {:error, :no_active_subscription}
      subscription -> {:ok, subscription}
    end
  end

  defp create_subscription(account_id, plan) do
    now = utc_now()
    {status, trial_ends_at} = trial_attrs(plan, now)

    %Subscription{}
    |> Subscription.changeset(%{
      account_id: account_id,
      plan_id: plan.id,
      status: status,
      trial_ends_at: trial_ends_at,
      current_period_start: now,
      current_period_end: DateTime.add(now, 30, :day)
    })
    |> Config.repo().insert()
  end

  defp trial_attrs(%Plan{trial_days: days}, now) when days > 0 do
    {"trialing", DateTime.add(now, days, :day)}
  end

  defp trial_attrs(_plan, _now), do: {"active", nil}

  defp utc_now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end
end
