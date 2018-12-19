defmodule WhistleTest do
  use ExUnit.Case
  doctest Whistle

  alias Whistle.{Html, Dom}

  test "greets the world" do
    model =
      Whistle.init()
      |> Whistle.update({:change_text, "hola"})
      |> Whistle.update(:add_task)

    view1 =
      model
      |> Whistle.view()
      |> IO.inspect()

    view2 =
      model
      |> Whistle.update({:change_text, "xxx"})
      |> Whistle.update(:add_task)
      |> Whistle.view()
      |> IO.inspect()

    Dom.diff([], {0, view1}, {0, view2})
    |> IO.inspect()
    |> Dom.serialize_patches()
    |> IO.inspect()
  end
end
