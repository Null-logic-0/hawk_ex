defmodule HawkEx.Entitlements do
  @moduledoc """
  Determines what an account is allowed to do based on their
  current plan and its features.

  ## The three functions

  `allowed?/2` — fast boolean check. Use this for conditionals,
  UI rendering, and access gates. No subscription = false.

      if HawkEx.allowed?(account, :export_csv), do: export()

  `check_entitlement/2` — diagnostic check. Use this when the
  caller needs to know *why* access was denied.

      case HawkEx.check_entitlement(account, :export_csv) do
        :ok                            -> proceed()
        {:error, :no_subscription}     -> show_subscribe_prompt()
        {:error, :feature_not_included} -> show_upgrade_prompt()
      end

  `remaining/2` — for limit-type features. Returns how much the
  plan allows, not how much the account has used.

      NOTE: v0.1 returns the plan limit, not actual remaining quota.
      Usage tracking will be added in a future version.

      case HawkEx.remaining(account, :api_calls) do
        :unlimited -> proceed()
        n when n > 0 -> proceed()
        0 -> deny()
      end
  """

  import Ecto.Query

  alias HawkEx.Config
  alias HawkEx.Billing
  alias HawkEx.Billing.{Feature, PlanFeature}

  # ---Public API---------------------------------------------------

  @doc """
  Returns true if the account is allowed to use the feature.
  Returns false if the account has no subscription or the feature
  is not included in their plan.
  """

  def allowed?(account, feature_key) do
    case check_entitlement(account, feature_key) do
      :ok -> true
      {:error, _} -> false
    end
  end

  @doc """
  Returns :ok if the account can use the feature, or a tagged error
    describing why access was denied.

    Errors:
      {:error, :no_subscription}      — account has no active plan
      {:error, :feature_not_included} — plan does not include this feature
  """
  def check_entitlement(account, feature_key) do
    key = to_string(feature_key)

    with {:ok, plan} <- get_active_plan(account),
         {:ok, plan_feature} <- get_plan_feature(plan.id, key) do
      evaluate_access(plan_feature)
    end
  end

  @doc """
  Returns the limit value for a limit-type feature.

  Returns:
    :unlimited           — feature is unlimited on this plan
    n (integer)          — plan allows this many (not remaining quota)
    {:error, reason}     — no subscription or feature not on plan

  NOTE: This returns the plan-defined limit, not actual remaining
  usage. Usage tracking against this limit is the host application's
  responsibility in v0.1.
  """

  def remaining(account, feature_key) do
    key = to_string(feature_key)

    with {:ok, plan} <- get_active_plan(account),
         {:ok, plan_feature} <- get_plan_feature(plan.id, key) do
      parse_limit(plan_feature)
    end
  end

  @doc """
  Returns the full entitlements matrix for display — all features,
  all active plans, and the value each plan grants for each feature.

  Returns a map with:
    * `:plans` — list of active plans, ordered by trial_days ascending
    * `:features` — list of all features
    * `:matrix` — map of `{plan_id, feature_key}` → value string
  """

  def matrix do
    plans =
      Config.repo().all(
        from(p in HawkEx.Billing.Plan,
          where: p.status == "active",
          order_by: [asc: p.trial_days]
        )
      )

    features = Config.repo().all(Feature)

    plan_features =
      Config.repo().all(
        from(pf in PlanFeature,
          preload: [:feature]
        )
      )

    matrix =
      Map.new(plan_features, fn pf ->
        {{pf.plan_id, pf.feature.key}, pf.value}
      end)

    %{plans: plans, features: features, matrix: matrix}
  end

  @doc """
  Returns all entitlement values for an account's current plan.

  Returns `{:ok, %{plan: Plan.t(), features: [%{key, feature_type, value}]}}`
  or `{:error, :no_subscription}` if the account has no active plan.
  """

  def for_account(account) do
    account_id = extract_account_id(account)

    case Billing.current_plan(account_id) do
      nil ->
        {:error, :no_subscription}

      plan ->
        features =
          Config.repo().all(
            from(pf in HawkEx.Billing.PlanFeature,
              join: f in HawkEx.Billing.Feature,
              on: f.id == pf.feature_id,
              where: pf.plan_id == ^plan.id,
              select: %{
                key: f.key,
                description: f.description,
                feature_type: f.feature_type,
                value: pf.value
              }
            )
          )

        {:ok, %{plan: plan, features: features}}
    end
  end

  # ---Private helpers-----------------------------------------------

  defp extract_account_id(%{id: id}), do: id
  defp extract_account_id(id) when is_binary(id), do: id

  defp get_active_plan(account) do
    case Billing.current_plan(account) do
      nil -> {:error, :no_subscription}
      plan -> {:ok, plan}
    end
  end

  defp get_plan_feature(plan_id, key) do
    result =
      Config.repo().one(
        from(pf in PlanFeature,
          join: f in Feature,
          on: f.id == pf.feature_id,
          where: pf.plan_id == ^plan_id,
          where: f.key == ^key,
          preload: [:feature]
        )
      )

    case result do
      nil -> {:error, :feature_not_included}
      plan_feature -> {:ok, plan_feature}
    end
  end

  # Boolean features
  defp evaluate_access(%PlanFeature{value: "true"}), do: :ok
  defp evaluate_access(%PlanFeature{value: "false"}), do: {:error, :feature_not_included}

  # Limit features — zero means the feature exists but is not granted
  defp evaluate_access(%PlanFeature{value: "0"}), do: {:error, :feature_not_included}

  # Unlimited or any positive limit — feature is accessible
  defp evaluate_access(%PlanFeature{value: _}), do: :ok

  # Limit parsing
  defp parse_limit(%PlanFeature{value: "unlimited"}), do: :unlimited

  defp parse_limit(%PlanFeature{value: value}) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> {:error, :invalid_limit_value}
    end
  end
end
