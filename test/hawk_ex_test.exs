defmodule HawkExTest do
  use ExUnit.Case, async: false

  alias HawkEx.Billing.{Feature, Plan, PlanFeature, Subscription}

  setup do
    Application.put_env(:hawk_ex, :repo, HawkEx.TestRepo)
    HawkEx.TestRepo.reset()

    plan = %Plan{id: Ecto.UUID.generate(), name: "pro", display_name: "Pro"}
    subscription = %Subscription{id: Ecto.UUID.generate(), account_id: Ecto.UUID.generate()}

    HawkEx.TestRepo.put_subscription(subscription, plan)

    %{plan: plan, subscription: subscription}
  end

  describe "delegated entitlement checks" do
    test "allowed?/2 returns true when the account plan grants a boolean feature", %{plan: plan} do
      feature = %Feature{id: Ecto.UUID.generate(), key: "export_csv", feature_type: "boolean"}
      plan_feature = %PlanFeature{plan_id: plan.id, feature: feature, value: "true"}

      HawkEx.TestRepo.put_plan_features(:export_csv, [plan_feature])

      assert HawkEx.allowed?(%{id: Ecto.UUID.generate()}, :export_csv)
      assert HawkEx.check_entitlement(%{id: Ecto.UUID.generate()}, :export_csv) == :ok
    end

    test "allowed?/2 returns false when the plan does not include the feature" do
      HawkEx.TestRepo.put_plan_features(:export_csv, [])

      refute HawkEx.allowed?(%{id: Ecto.UUID.generate()}, :export_csv)

      assert HawkEx.check_entitlement(%{id: Ecto.UUID.generate()}, :export_csv) ==
               {:error, :feature_not_included}
    end

    test "check_entitlement/2 reports when the account has no subscription" do
      HawkEx.TestRepo.reset()

      assert HawkEx.check_entitlement(%{id: Ecto.UUID.generate()}, :export_csv) ==
               {:error, :no_subscription}
    end

    test "remaining/2 returns numeric and unlimited limits", %{plan: plan} do
      api_calls = %Feature{id: Ecto.UUID.generate(), key: "api_calls", feature_type: "limit"}
      seats = %Feature{id: Ecto.UUID.generate(), key: "seats", feature_type: "limit"}

      HawkEx.TestRepo.put_plan_features(:api_calls, [
        %PlanFeature{plan_id: plan.id, feature: api_calls, value: "1000"}
      ])

      assert HawkEx.remaining(%{id: Ecto.UUID.generate()}, :api_calls) == 1000

      HawkEx.TestRepo.put_plan_features(:seats, [
        %PlanFeature{plan_id: plan.id, feature: seats, value: "unlimited"}
      ])

      assert HawkEx.remaining(%{id: Ecto.UUID.generate()}, :seats) == :unlimited
    end
  end
end
