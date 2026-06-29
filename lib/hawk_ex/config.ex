defmodule HawkEx.Config do
  @moduledoc false

  @doc "Returns the configured Ecto repo module."
  def repo do
    Application.fetch_env!(:hawk_ex, :repo)
  rescue
    KeyError ->
      raise """
      hawk_ex requires a repo to be configured.

      Add this to your config/config.exs:

      config :hawk_ex, repo: MyApp.Repo
      """
  end

  @doc "Returns the configured account schema module."
  def account_schema do
    Application.fetch_env!(:hawk_ex, :account_schema)
  rescue
    KeyError ->
      raise """
      hawk_ex requires an account schema to be configured.

      Add this to your config/config.exs:

      config :hawk_ex, account_schema: MyApp.AccountSchema.Organization
      """
  end

  @doc """
  Returns the configured PubSub module, or nil if not configured.
  PubSub is optional — events are a no-op when not configured.
  """
  def pubsub do
    Application.get_env(:hawk_ex, :pubsub, nil)
  end
end
