defmodule HawkEx.Billing.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Represents an account's current relationship to a Plan.

  Subscriptions are never deleted. When a subscription ends, its
  status transitions to `canceled`. When an account resubscribes,
  a new subscription record is created. This gives you a complete
  history for auditing and debugging without soft-delete complexity.

  ## Status lifecycle

      trialing ──► active ──► past_due ──► canceled
           │                              ▲
           └──────────────────────────────┘

  ## Active statuses
  Both `trialing` and `active` are considered "active" for
  entitlement purposes. Use `Subscription.active_statuses/0`
  to reference this list — never hardcode it.

  ## One active subscription per account
  Enforced by a partial unique index on `account_id` where
  status is in active_statuses. This is also validated at the
  context level in HawkEx.Billing before insert.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(trialing active past_due canceled)
  @active_statuses ~w(trialing active)

  schema "hawk_ex_subscriptions" do
    field(:account_id, :binary_id)

    belongs_to(:plan, HawkEx.Billing.Plan)

    field(:status, :string, default: "active")
    field(:trial_ends_at, :utc_datetime)
    field(:current_period_start, :utc_datetime)
    field(:current_period_end, :utc_datetime)
    field(:canceled_at, :utc_datetime)
    field(:external_id, :string)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :account_id,
      :plan_id,
      :status,
      :trial_ends_at,
      :current_period_start,
      :current_period_end,
      :canceled_at,
      :external_id,
      :metadata
    ])
    |> validate_required([:account_id, :plan_id, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:account_id,
      name: :hawk_ex_subscriptions_one_active_per_account,
      message: "account already has an active subscription"
    )
  end

  def valid_statuses, do: @valid_statuses

  @doc "Statuses that grant entitlement access."
  def active_statuses, do: @active_statuses
end
