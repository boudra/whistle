defmodule WhistleTest do
  use ExUnit.Case
  doctest Whistle

  alias Whistle.{Html, Dom}

  test "greets the world" do
    # model =
    #   Whistle.init()
    #   |> Whistle.update({:increment, 5})
    #
    # view1 =
    #   model
    #   |> Whistle.view()
    #   |> IO.inspect()
    #
    # view2 =
    #   model
    #   |> Whistle.update({:decrement})
    #   |> Whistle.view()
    #   |> Whistle.Html.to_string()
    #   |> IO.inspect()

    node1 =
      {0,
       Html.div([class: "text"], [
         Html.p([], [Html.text("hello")]),
         Html.p([], [Html.text("Hola")])
       ])}
      |> IO.inspect()

    node2 =
      {0,
       Html.div([class: "text"], [
         Html.p([], [Html.text("Hola")]),
         Html.div([], [Html.text("hello")])
       ])}
      |> IO.inspect()

    # diff =
    #   [
    #     {:replace_tag, [0, 0], "div"},
    #     {:replace_text, [0, 1, 0], "Adeu"}
    #   ]

    Dom.diff([], node1, node2)
    |> IO.inspect()
    |> Dom.serialize_patches()
    |> IO.inspect()
  end
end
