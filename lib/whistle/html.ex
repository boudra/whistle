defmodule Whistle.Html do
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

  def div(attributes, children) do
    node("div", attributes, children)
  end

  def p(attributes, children) do
    node("p", attributes, children)
  end

  def a(attributes, children) do
    node("a", attributes, children)
  end

  def h1(attributes, children) do
    node("h1", attributes, children)
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

  def html(attributes, children) do
    node("html", attributes, children)
  end

  def head(attributes, children) do
    node("head", attributes, children)
  end

  def body(attributes, children) do
    node("body", attributes, children)
  end

  def meta(attributes) do
    node("meta", attributes, [])
  end

  def title(children) do
    node("title", [], children)
  end

  def script(attributes) do
    node("script", attributes, [])
  end

  def script(attributes, children) do
    node("script", attributes, children)
  end

  def br() do
    node("br", [], [])
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
