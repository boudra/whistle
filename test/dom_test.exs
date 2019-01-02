defmodule DomTest do
  use ExUnit.Case
  doctest Whistle

  alias Whistle.{Html, Dom}

  test "html helpers" do
    assert Html.p([], []) == Html.node("p", [], [])
    assert Html.p([], []) == {"p", [], []}
    assert Html.p([class: "class"], []) == {"p", [class: "class"], []}
    assert Html.p([class: "class"], "some text") == {"p", [class: "class"], [{0, {:text, [], "some text"}}]}
    assert Html.p([class: "class"], [Html.text("some text")]) == Html.p([class: "class"], "some text")
  end

  test "dom diff" do
    assert Dom.diff(Html.p([id: "id"], []), Html.p([id: "id"], [])) == []
    assert Dom.diff(Html.p([id: "id"], []), Html.p([id: "new_id"], [])) == [
      {:set_attribute, [0], [:id, "new_id"]}
    ]
    assert Dom.diff(Html.p([], []), Html.p([id: "new_id"], [])) == [
      {:set_attribute, [0], [:id, "new_id"]}
    ]
    assert Dom.diff(Html.p([id: "id"], []), Html.p([], [])) == [
      {:remove_attribute, [0], :id}
    ]
    assert Dom.diff(nil, Html.p([id: "id"], [])) == [
      {:add_node, [], {0, Html.p([id: "id"], [])}}
    ]
    assert Dom.diff(Html.p([id: "id"], []), Html.div([id: "div"], [])) == [
      {:replace_node, [0], Html.div([id: "div"], [])}
    ]
    assert Dom.diff(Html.p([id: "id"], []), nil) == [
      {:remove_node, [0], []}
    ]
  end

end
