defmodule DomTest do
  use ExUnit.Case
  doctest Whistle

  alias Whistle.{Html, Html.Dom}
  require Whistle.Html

  # patch operation codes
  # TODO: macro to import these from the Dom module
  @add_node 2
  @replace_node 3
  @remove_node 4
  @set_attribute 5
  @remove_attribute 6
  @add_event_handler 7
  @remove_event_handler 8

  def diff_patches(node1, node2) do
    Dom.diff(node1, node2).patches
  end

  test "html helpers" do
    assert Html.p([], []) == Html.node("p", [], [])
    assert Html.p([], []) == {"p", {[], []}}
    assert Html.p([class: "class"], []) == {"p", {[class: "class"], []}}

    assert Html.p([class: "class"], "some text") == {"p", {[class: "class"], [{0, "some text"}]}}

    assert Html.p([class: "class"], [Html.text("some text")]) ==
             Html.p([class: "class"], "some text")
  end

  test "dom diff" do
    assert diff_patches(Html.p([id: "id"], []), Html.p([id: "id"], [])) == []

    assert diff_patches(Html.p([id: "id"], []), Html.p([id: "new_id"], [])) == [
             [@set_attribute, [0], [:id, "new_id"]]
           ]

    assert diff_patches(Html.p([], []), Html.p([id: "new_id"], [])) == [
             [@set_attribute, [0], [:id, "new_id"]]
           ]

    assert diff_patches(Html.p([id: "id"], []), Html.p([], [])) == [
             [@remove_attribute, [0], :id]
           ]

    assert diff_patches(nil, Html.p([id: "id"], [])) == [
             [@add_node, [], ["p", %{"id" => "id"}, []]]
           ]

    assert diff_patches(Html.p([id: "id"], []), Html.div([id: "div"], [])) == [
             [@replace_node, [0], ["div", %{"id" => "div"}, []]]
           ]

    assert diff_patches(Html.p([id: "id"], []), nil) == [
             [@remove_node, [0]]
           ]

    assert diff_patches(Html.p([id: "id"], [Html.text("")]), Html.p([id: "id"], [])) == [
             [@remove_node, [0, 0]]
           ]
  end

  describe "lazy dom" do
    test "doesn't call fun when args are the same" do
      fun = fn text ->
        raise text
      end

      assert diff_patches(
               Html.lazy(fun, ["hello"]),
               Html.lazy(fun, ["hello"])
             ) == []
    end

    test "diffs when args are different" do
      fun = fn text ->
        Html.text(text)
      end

      assert diff_patches(
               Html.lazy(fun, ["hello"]),
               Html.lazy(fun, ["hello world"])
             ) == [[@replace_node, [0], "hello world"]]
    end
  end

  describe "event handlers" do
    test "get added when new" do
      node = Html.p([on: [click: "something"]], "test")

      assert %{
               handlers: [
                 {:put, "0.click", %{msg: "something"}}
               ],
               patches: [
                 [@add_node | _],
                 [@add_event_handler, [0], _]
               ]
             } = Dom.diff(nil, node)
    end

    test "get changed" do
      node = Html.p([on: [click: "something"]], "test")

      node2 = Html.p([on: [click: "something else"]], "test")

      assert %{
               handlers: [
                 {:put, "0.click", %{msg: "something else"}}
               ],
               patches: [
                 [@remove_event_handler, [0], :click],
                 [@add_event_handler, [0], %{event: :click}]
               ]
             } = Dom.diff(node, node2)
    end
  end
end
