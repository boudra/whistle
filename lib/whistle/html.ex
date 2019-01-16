defmodule Whistle.Html do
  @tags [
    :div,
    :img,
    :a,
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
    :h4,
  ]

  for tag <- @tags do
    tag_name = Atom.to_string(tag)

    def unquote(tag)(attributes \\ [], children \\ []) do
      node(unquote(tag_name), attributes, children)
    end
  end

  def node(tag, attributes, text) when is_binary(text) do
    node(tag, attributes, [text])
  end

  def node(tag, attributes, children) do
    children =
      children
      |> Enum.with_index()
      |> Enum.map(fn {node, index} ->
        {index, node}
      end)

    {tag, attributes, children}
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
