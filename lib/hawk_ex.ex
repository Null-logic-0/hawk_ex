defmodule HawkEx do
  @moduledoc """
  HAWK_EX — Phoenix SaaS infrastructure toolkit.

  The top-level module provides the most common entitlement functions
  as a convenience. Full APIs are available on the sub-modules:

    HawkEx.Billing       — plan and subscription management
    HawkEx.Entitlements  — feature access and limits

  ## Quick start

      # Gate a feature
      if HawkEx.allowed?(account, :export_csv) do
        export(data)
      end

      # Diagnostic check with reason
      case HawkEx.check_entitlement(account, :export_csv) do
        :ok                             -> export(data)
        {:error, :no_subscription}      -> redirect_to_pricing()
        {:error, :feature_not_included} -> redirect_to_upgrade()
      end

      # Check a plan limit
      case HawkEx.remaining(account, :api_calls) do
        :unlimited -> proceed()
        n when n > 0 -> proceed()
        _ -> deny()
      end
  """

  alias HawkEx.Entitlements

  defdelegate allowed?(account, feature), to: Entitlements
  defdelegate check_entitlement(account, feature), to: Entitlements
  defdelegate remaining(account, feature), to: Entitlements
end
