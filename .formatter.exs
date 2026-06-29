# Used by "mix format"
[
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}"
    # priv/templates/ is intentionally excluded — EEx templates
    # cannot be formatted with the standard Elixir formatter.
  ]
]
