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
      build_quoted_node(unquote(tag_name), attributes, children)
    end
  end

  defmacro node(tag, attributes, children) do
    build_quoted_node(tag, attributes, children)
  end

  def text(content) do
    to_string(content)
  end

  def lazy(fun, args) do
    {:lazy, {fun, args}}
  end

  def program(name, params) do
    {:program, {name, params}}
  end

  @doc false
  def build_children(children) when is_list(children) do
    children
    |> List.flatten()
    |> Enum.with_index()
    |> Enum.map(fn
      {child = {index, _node}, _} when is_integer(index) ->
        child

      {node, index} ->
        {index, node}
    end)
  end

  def build_children(children) do
    children
  end

  @doc false
  def build_quoted_node(tag, attributes, node) when not is_list(node) do
    build_quoted_node(tag, attributes, [node])
  end

  def build_quoted_node(tag, attributes, children) do
    new_children =
      if Macro.quoted_literal?(children) do
        build_children(children)
      else
        quote do
          unquote(children)
          |> List.flatten()
          |> Whistle.Html.build_children()
        end
      end

    {tag, {attributes, new_children}}
  end

  @doc false
  def build_node(tag, attributes, node) when not is_list(node) do
    build_node(tag, attributes, [node])
  end

  def build_node(tag, attributes, children) do
    {tag, {attributes, build_children(children)}}
  end
end
