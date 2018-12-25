defmodule Whistle.Dom do
  @type t() :: tuple()

  defp zip([lh | lt], [rh | rt]) do
    [{lh, rh} | zip(lt, rt)]
  end

  defp zip([], []), do: []
  defp zip([lh | lt], []), do: zip([lh | lt], [nil])
  defp zip([], [rh | rt]), do: zip([nil], [rh | rt])

  def diff_text({key, {:text, [], text}}, {key, {:text, [], text}}) do
    []
  end

  def diff_text({key, {:text, [], _}}, {key, {:text, [], text2}}) do
    [{:replace_text, [key], text2}]
  end

  def diff_text({key, _}, {key, _}) do
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

  def diff_children({key, _}, {key, _}) do
    []
  end

  def diff_attributes({key, {_, attributes, _}}, {key, {_, new_attributes, _}}) do
    attributes
    |> Keyword.keys()
    |> Enum.concat(Keyword.keys(new_attributes))
    |> Enum.uniq()
    |> Enum.reduce(
      [],
      fn
        :on, patches ->
          patches

        name, patches ->
          value = Keyword.get(attributes, name)
          new_value = Keyword.get(new_attributes, name)

          case {value, new_value} do
            {value, value} ->
              []

            {_, nil} ->
              [{:remove_attribute, [key], name}]

            {_, new_value} ->
              [{:set_attribute, [key], [name, new_value]}]
          end ++ patches
      end
    )
  end

  def diff(_path, nil, nil) do
    []
  end

  def diff(path, nil, {key, new_node}) do
    [
      {:add_node, path, {key, new_node}}
    ]
  end

  def diff(path, {key, {tag, _, _}}, {key, new_node = {new_tag, _, _}})
      when tag != new_tag do
    [
      {:replace_node, path ++ [key], new_node}
    ]
  end

  def diff(path, node1, node2) do
    []
    |> Enum.concat(diff_attributes(node1, node2))
    |> Enum.concat(diff_text(node1, node2))
    |> Enum.concat(diff_children(node1, node2))
    |> Enum.map(fn {op, key, value} ->
      {op, path ++ key, value}
    end)
  end

  def extract_event_handlers(path, {key, {_, attributes, children}}) do
    key = path ++ [key]
    string_key = Enum.join(key, ".")

    handlers =
      attributes
      |> Keyword.get(:on)
      |> case do
        nil ->
          []

        handlers ->
          Enum.map(handlers, fn {type, msg} ->
            {string_key <> "." <> Atom.to_string(type), msg}
          end)
      end

    child_handlers =
      if is_list(children) do
        Enum.reduce(children, [], fn node, handlers ->
          handlers ++ extract_event_handlers(key, node)
        end)
      else
        []
      end

    handlers ++ child_handlers
  end

  def serialize_virtual_dom(path, {key, {tag, attributes, children}}) do
    key = path ++ [key]

    attributes =
      attributes
      |> Enum.concat(key: Enum.join(key, "."))
      |> Enum.map(fn
        {:on, handlers} ->
          {"on", Keyword.keys(handlers)}

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

      {:add_node, path, data} ->
        ["add_node", path, serialize_virtual_dom(path, data)]

      {op, path, data} ->
        [Atom.to_string(op), path, data]
    end)
  end
end
