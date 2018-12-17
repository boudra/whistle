defmodule Whistle.Html do
  defp zip([lh | lt], [rh | rt]) do
    [{lh, rh} | zip(lt, rt)]
  end

  defp zip([], []), do: []
  defp zip([lh | lt], []), do: zip([lh | lt], [nil])
  defp zip([], [rh | rt]), do: zip([nil], [rh | rt])

  defp attributes_to_string(attributes) do
    attributes
    |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Enum.map(fn
      {"on_" <> input, msg} ->
        ~s/onclick="socket.send('x')"/

      {key, value} ->
        ~s(#{key}="#{value}")
    end)
    |> Enum.join(" ")
  end

  def diff_text({key, {:text, [], text}}, {key, {:text, [], text}}) do
    []
  end

  def diff_text({key, {:text, [], text}}, {key, {:text, [], text2}}) do
    [{:replace_text, [key], text2}]
  end

  def diff_text({_key, _}, {_key, _}) do
    []
  end

  def diff_children({key, {_, _, children}}, {key, {_, _, new_children}})
      when is_list(children) and is_list(new_children) do
    children
    |> zip(new_children)
    |> Enum.reduce([], fn {a, b}, ops ->
      ops ++ diff([key], a, b)
    end)
  end

  def diff_children({_key, _}, {_key, _}) do
    []
  end

  def diff(path, {key, node = {tag, _, _}}, {key, new_node = {new_tag, _, _}})
      when tag != new_tag do
    [
      {:replace_node, path, new_node}
    ]
  end

  def diff(path, {key, node}, {key, node}) do
    []
  end

  def diff(path, node1, node2) do
    []
    |> Enum.concat(diff_text(node1, node2))
    |> Enum.concat(diff_children(node1, node2))
    |> Enum.map(fn {op, key, value} ->
      {op, path ++ key, value}
    end)
  end

  def to_string(node = {tag, attributes, content}) do
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

  def text(content) do
    {:text, [], content}
  end

  def serialize_virtual_dom(path, {key, {tag, attributes, children}}) do
    key = path ++ [key]

    attributes =
      attributes
      |> Enum.concat(key: Enum.join(key, "."))
      |> Enum.map(fn
        {k, v} when not is_binary(v) ->
          {Atom.to_string(k), ""}

        {k, v} ->
          {Atom.to_string(k), v}
      end)
      |> Enum.into(%{})

    children =
      if is_list(children) do
        Enum.map(children, fn node ->
          serialize_virtual_dom(key, node)
        end)
      else
        children
      end

    [tag, attributes, children]
  end

  def serialize_patches(patches) do
    patches
    |> Enum.map(fn
      {:replace_node, path, data} ->
        ["replace_node", path, serialize_virtual_dom(path, {0, data})]

      {:replace_text, path, data} ->
        ["replace_text", path, data]
    end)
    |> IO.inspect()
    |> Jason.encode!()
  end
end
