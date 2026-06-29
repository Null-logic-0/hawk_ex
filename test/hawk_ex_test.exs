defmodule HawkExTest do
  use ExUnit.Case
  doctest HawkEx

  test "greets the world" do
    assert HawkEx.hello() == :world
  end
end
