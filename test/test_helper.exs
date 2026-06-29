ExUnit.start()

defmodule HawkEx.TestRepo do
  @moduledoc false

  alias HawkEx.Billing.{Feature, PlanFeature, Subscription}

  def one(%Ecto.Query{from: %{source: {"hawk_ex_subscriptions", Subscription}}}) do
    case Process.get({__MODULE__, :subscription}) do
      nil -> nil
      subscription -> %{subscription | plan: Process.get({__MODULE__, :plan})}
    end
  end

  def one(%Ecto.Query{from: %{source: {"hawk_ex_plan_features", PlanFeature}}}) do
    key = Process.get({__MODULE__, :feature_key})

    Process.get({__MODULE__, :plan_features}, [])
    |> Enum.find(fn %{feature: %Feature{key: feature_key}} -> feature_key == key end)
  end

  def put_subscription(subscription, plan) do
    Process.put({__MODULE__, :subscription}, subscription)
    Process.put({__MODULE__, :plan}, plan)
  end

  def put_plan_features(feature_key, plan_features) do
    Process.put({__MODULE__, :feature_key}, to_string(feature_key))
    Process.put({__MODULE__, :plan_features}, plan_features)
  end

  def reset do
    Process.delete({__MODULE__, :subscription})
    Process.delete({__MODULE__, :plan})
    Process.delete({__MODULE__, :feature_key})
    Process.delete({__MODULE__, :plan_features})
  end
end
