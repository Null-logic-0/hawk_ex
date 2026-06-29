defmodule HawkEx.Billing.ChangesetTest do
  use ExUnit.Case, async: true

  alias HawkEx.Billing.{Feature, Plan, PlanFeature, Subscription}

  describe "plan changeset" do
    test "requires a machine name and display name" do
      changeset = Plan.changeset(%Plan{}, %{})

      refute changeset.valid?
      assert %{name: ["can't be blank"], display_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts lowercase slug names and known statuses" do
      changeset =
        Plan.changeset(%Plan{}, %{
          name: "team_pro",
          display_name: "Team Pro",
          status: "active",
          trial_days: 14
        })

      assert changeset.valid?
    end

    test "rejects display-style names and unknown statuses" do
      changeset =
        Plan.changeset(%Plan{}, %{name: "Team Pro", display_name: "Team Pro", status: "draft"})

      refute changeset.valid?

      assert %{
               name: ["must be lowercase letters, numbers, and underscores only"],
               status: ["is invalid"]
             } =
               errors_on(changeset)
    end
  end

  describe "feature changeset" do
    test "requires a key and type" do
      changeset = Feature.changeset(%Feature{}, %{})

      refute changeset.valid?
      assert %{key: ["can't be blank"], feature_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts supported feature types" do
      assert Feature.changeset(%Feature{}, %{key: "export_csv", feature_type: "boolean"}).valid?
      assert Feature.changeset(%Feature{}, %{key: "api_calls", feature_type: "limit"}).valid?
    end

    test "rejects unsupported types and invalid keys" do
      changeset = Feature.changeset(%Feature{}, %{key: "Export CSV", feature_type: "flag"})

      refute changeset.valid?

      assert %{
               key: ["must be lowercase letters, numbers and underscores only"],
               feature_type: ["must be 'boolean' or 'limit'"]
             } = errors_on(changeset)
    end
  end

  describe "plan feature changeset" do
    test "requires both sides of the relationship and a value" do
      changeset = PlanFeature.changeset(%PlanFeature{}, %{})

      refute changeset.valid?

      assert %{
               plan_id: ["can't be blank"],
               feature_id: ["can't be blank"],
               value: ["can't be blank"]
             } =
               errors_on(changeset)
    end
  end

  describe "subscription changeset" do
    test "requires account and plan while defaulting status" do
      changeset = Subscription.changeset(%Subscription{}, %{})

      refute changeset.valid?
      assert %{account_id: ["can't be blank"], plan_id: ["can't be blank"]} = errors_on(changeset)
      assert Ecto.Changeset.get_field(changeset, :status) == "active"
    end

    test "accepts all documented statuses" do
      for status <- Subscription.valid_statuses() do
        changeset =
          Subscription.changeset(%Subscription{}, %{
            account_id: Ecto.UUID.generate(),
            plan_id: Ecto.UUID.generate(),
            status: status
          })

        assert changeset.valid?
      end
    end

    test "exposes active statuses used for entitlement checks" do
      assert Subscription.active_statuses() == ["trialing", "active"]
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
