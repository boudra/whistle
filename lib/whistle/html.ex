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
    :h4,
  ]

  for tag <- @tags do
    tag_name = Atom.to_string(tag)

    defmacro unquote(tag)(attributes \\ [], children \\ []) do
      node = build_node(unquote(tag_name), attributes, children)
      Macro.escape(node, unquote: true)
    end
  end

  defp maybe_unquote([]) do
    []
  end

  defp maybe_unquote(arg) do
    {:unquote, [], [arg]}
  end

  def build_children(children) when is_list(children) do
    children
    |> Enum.with_index()
    |> Enum.map(fn {node, index} ->
      {index, node}
    end)
  end

  def build_children(children) do
    quote do
      unquote(children)
      |> Whistle.Html.build_children()
    end
  end

  def build_node(tag, attributes, text) when is_binary(text) do
    build_node(tag, attributes, [text])
  end

  def build_node(tag, attributes, children) do
    children =
      build_children(children)

    {tag, maybe_unquote(attributes), maybe_unquote(children)}
  end

  defmacro node(tag, attributes, children) do
    node = build_node(tag, attributes, children)
    Macro.escape(node, unquote: true)
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
