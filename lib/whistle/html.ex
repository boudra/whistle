defmodule Whistle.Html do
  @tags [
    :div,
    :img,
    :a,
    :i,
    :form,
    :table,
    :tr,
    :td,
    :tbody,
    :thead,
    :select,
    :option,
    :section,
    :header,
    :footer,
    :nav,
    :ul,
    :ol,
    :li,
    :input,
    :button,
    :br,
    :p,
    :b,
    :strong,
    :center,
    :span,
    :html,
    :body,
    :head,
    :script,
    :link,
    :h1,
    :h2,
    :h3,
    :h4
  ]

  for tag <- @tags do
    tag_name = Atom.to_string(tag)

    defmacro unquote(tag)(attributes \\ [], children \\ []) do
      build_node(unquote(tag_name), attributes, children)
    end
  end

  def build_children(children) when is_list(children) do
    children
    |> List.flatten()
    |> Enum.with_index()
    |> Enum.map(fn {node, index} ->
      {index, node}
    end)
  end

  def build_children(children) do
    build_children([children])
  end

  def build_node(tag, attributes, text) when is_binary(text) do
    build_node(tag, attributes, [text])
  end

  def build_node(tag, attributes, children) do
    children = build_children(children)

    {tag, {attributes, children}}
  end

  defmacro node(tag, attributes, children) do
    build_node(tag, attributes, children)
  end

  def text(content) do
    to_string(content)
  end

  def lazy(fun, args) do
    {:lazy, fun, args}
  end

  def program(name, params) do
    {:program, name, params}
  end
end
