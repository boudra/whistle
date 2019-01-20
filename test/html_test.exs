defmodule HtmlTest do
  use ExUnit.Case
  doctest Whistle
  import Whistle.Html.Parser

  require Whistle.Html
  alias Whistle.Html

  test "html parser" do
    number = 5

    assert ~H"" == nil
    assert ~H"some text" == Html.text("some text")
    assert ~H"<%= number %>" == Html.text(number)
    assert ~H(<!-- test -->) == nil
    assert ~H"<div></div>" == Html.div()
    assert ~H(<input key="value" />) == Html.input(key: "value")
    assert ~H(<div key="value"></div>) == Html.div(key: "value")
    assert ~H(<div key=<%= number %>></div>) == Html.div(key: number)
    assert ~H(<div on-click=<%= :test %>></div>) == Html.div(on: [click: :test])
    assert ~H(<div key=<%= number %>><span></span></div>) ==
             Html.div([key: number], [
               Html.span()
             ])
  end
end
