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

  @doc """
  Returns the configured Oban module, or nil if not configured.
  Required for async CSV exports.
  """
  def oban do
    Application.get_env(:hawk_ex, :oban, nil)
  end

  @doc """
  Returns the configured CSV storage adapter and its options.
  Defaults to local disk at priv/exports.
  """
  def csv_storage do
    case Application.get_env(:hawk_ex, :csv_storage, nil) do
      nil ->
        {HawkEx.CSV.Storage.Local, path: "priv/exports"}

      {adapter, opts} when is_list(opts) ->
        {adapter, opts}

      adapter when is_atom(adapter) ->
        {adapter, []}
    end
  end
end
