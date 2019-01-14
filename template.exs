defmodule WhistleEngine do
  use EEx.Engine

  def handle_body(quoted) do
    IO.inspect {:body, quoted}
    EEx.Engine.handle_body(quoted)
  end

  def handle_begin(quoted) do
    IO.inspect {:begin, quoted}
    EEx.Engine.handle_begin(quoted)
  end

  def handle_end(quoted) do
    IO.inspect {:end, quoted}
    EEx.Engine.handle_end(quoted)
  end

  def handle_text(buffer, text) do
    IO.inspect {:text, text}
    EEx.Engine.handle_text(buffer, text)
  end

  def handle_expr(buffer, marker, expr) do
    IO.inspect {:expr, expr}
    quote do
      tmp1 = unquote(buffer)
      tmp1 <> Macro.to_string(unquote(expr))
    end
  end
end

defmodule Template do
  defp node_eval_eex({tag, attributes, children}) do
    new_children =
      Enum.map(children, &node_eval_eex/1)
  end

  defmacro sigil_H(x, a) do
    IO.inspect({x, a})

    quote do
      EEx.eval_string(unquote(x), [], engine: WhistleEngine)
      Floki.parse(unquote(x))
    end
  end

  def view() do
    x = "hello"

    ~H"""
    <a on-click="<%= :submit %>">
    <%= for x <- ["X"] do %>
      <span><%= x %></span>
      <% end %>
    </a>
    """
  end
end

IO.inspect(Floki.parse("<div hello=\""))


