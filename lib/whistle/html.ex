defmodule Whistle.Html do

  defp attributes_to_string(attributes) do
    attributes
    |> Enum.map(fn
      {:on, _} ->
        ""

      {key, value} ->
        ~s(#{key}="#{value}")
    end)
    |> Enum.join(" ")
  end

  def to_string(node = {_, _, _}) do
    __MODULE__.to_string({0, node})
  end

  def to_string({_, {:text, [], content}}) do
    content
  end

  def to_string({key, {tag, attributes, children}}) do
    children =
      children
      |> Enum.map(&__MODULE__.to_string/1)
      |> Enum.join("")

    ~s(<#{tag} key="#{key}" #{attributes_to_string(attributes)}>#{children}</#{tag}>)
  end

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

  def br() do
    node("br", [], [])
  end

  def text(content) do
    {:text, [], Plug.HTML.html_escape(content)}
  end

end
