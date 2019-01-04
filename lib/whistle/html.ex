defmodule Whistle.Html do

  def node(tag, attributes, child) when is_binary(child) do
    node(tag, attributes, [text(child)])
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

  def div(attributes, children) do
    node("div", attributes, children)
  end

  def p(attributes, children) do
    node("p", attributes, children)
  end

  def button(attributes, children) do
    node("button", attributes, children)
  end

  def input(attributes) do
    node("input", attributes, [])
  end

  def ul(attributes, children) do
    node("ul", attributes, children)
  end

  def li(attributes, children) do
    node("li", attributes, children)
  end

  def strong(attributes, children) do
    node("strong", attributes, children)
  end

  def form(attributes, children) do
    node("form", attributes, children)
  end

  def br() do
    node("br", [], [])
  end

  def text(content) do
    {:text, [], content}
  end

  def lazy(fun, args) do
    {:lazy, fun, args}
  end

end
