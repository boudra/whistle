defmodule Whistle.Dom do
  @type t() :: tuple()

  defmodule Diff do
    defstruct lazy_trees: %{}, patches: [], handlers: []
  end

  # patch operation codes
  @add_node 2
  @replace_node 3
  @remove_node 4
  @set_attribute 5
  @remove_attribute 6
  @add_event_handler 7
  @remove_event_handler 8
  @replace_program 9

  def diff(element1, element2) do
    state = %Diff{}

    diff(state, [], {0, element1}, {0, element2})
  end

  def diff(trees, node1 = {0, _}, node2 = {0, _}) do
    diff(%Diff{lazy_trees: trees}, [], node1, node2)
  end

  def diff(trees, node1, node2) do
    diff(%Diff{lazy_trees: trees}, [], {0, node1}, {0, node2})
  end

  def diff(state, _path, {_, nil}, {_, nil}) do
    state
  end

  def diff(state, path, {_, nil}, {key, {:lazy, fun, args}}) do
    new_node = apply(fun, args)

    state
    |> put_lazy_tree({fun, args}, new_node)
    |> add_node(path, key, new_node)
  end

  def diff(
        state = %{lazy_trees: tree},
        path,
        {key, {:lazy, fun, args}},
        {key, {:lazy, new_fun, new_args}}
      ) do
    if fun === new_fun and args === new_args do
      state
    else
      new_node = apply(new_fun, new_args)

      case Map.get(tree, {fun, args}) do
        nil ->
          replace_node(state, path, key, new_node)

        old_node ->
          state
          |> put_lazy_tree({fun, args}, new_node)
          |> diff(path, {key, old_node}, {key, new_node})
      end
    end
  end


  def diff(state, path, {_, nil}, {key, new_node}) do
    add_node(state, path, key, new_node)
  end

  def diff(state, path, {key, {:program, _, _} = node}, {key, {:program, _, _} = node}) do
    state
  end

  def diff(state, path, {key, {:program, _, _}}, {key, {:program, program, params}}) do
    add_patches(state, [[@replace_program, path ++ [key], program, params]])
  end

  def diff(state, path, {key, node}, {key, new_node = {:program, _, _}}) do
    replace_node(state, path, key, new_node)
  end

  # TODO: create @remove_event_handler patches for the DOM
  def diff(state, path, {key, node}, {key, nil}) do
    %{state | patches: [[@remove_node, path ++ [key]] | state.patches]}
  end

  def diff(state, path, {key, {tag, _, _}}, {key, new_node = {new_tag, _, _}})
      when tag != new_tag do
    replace_node(state, path, key, new_node)
  end

  def diff(state, path, {key, node}, {key, node}) do
    state
  end

  def diff(state, path, {key, old_node}, {key, new_node}) when is_binary(new_node) do
    replace_node(state, path, key, new_node)
  end

  def diff(state, path, node1, node2) do
    state
    |> diff_attributes(path, node1, node2)
    |> diff_children(path, node1, node2)
  end

  def diff_children(state, path, {key, {_, _, children}}, {key, {_, _, new_children}})
      when is_list(children) and is_list(new_children) do
    children
    |> zip(new_children)
    |> Enum.reduce(state, fn {a, b}, state ->
      diff(state, path ++ [key], a, b)
    end)
  end

  def diff_children(state, path, {key, _}, {key, _}) do
    state
  end

  def diff_attributes(
        state = %{handlers: handlers, patches: patches},
        path,
        {key, {_, attributes, _}},
        {key, {_, new_attributes, _}}
      ) do
    new_patches =
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
                [[@remove_attribute, path ++ [key], name]]

              {_, new_value} ->
                [[@set_attribute, path ++ [key], [name, new_value]]]
            end ++ patches
        end
      )

    full_key = path ++ [key]
    string_key = Enum.join(full_key, ".")

    old_handlers =
      attributes
      |> Keyword.get_values(:on)
      |> Enum.reduce([], fn handlers, acc ->
        Enum.map(handlers, fn handler ->
          handler = build_event_handler(handler, full_key)

          type = Map.get(handler, :event)

          {type, handler}
        end) ++ acc
      end)
      |> Map.new()

    new_handlers =
      new_attributes
      |> Keyword.get_values(:on)
      |> Enum.reduce([], fn handlers, acc ->
        Enum.map(handlers, fn handler ->
          handler = build_event_handler(handler, full_key)
          type = Map.get(handler, :event)

          {type, handler}
        end) ++ acc
      end)
      |> Map.new()

    {new_handlers, new_patches} =
      Map.keys(old_handlers)
      |> Enum.concat(Map.keys(new_handlers))
      |> Enum.uniq()
      |> Enum.reduce({handlers, new_patches}, fn event, acc = {handlers, patches} ->
        value = Map.get(old_handlers, event)
        new_value = Map.get(new_handlers, event)
        handler_id = string_key <> "." <> Kernel.to_string(event)

        case {value, new_value} do
          {value, value} ->
            acc

          {_, nil} ->
            new_handlers = handlers ++ [{:delete, handler_id}]

            {new_handlers,
             patches ++
               [
                 [@remove_event_handler, full_key, event]
               ]}

          {nil, new_value} ->
            new_handlers = handlers ++ [{:put, handler_id, new_value}]

            {new_handlers,
             patches ++
               [
                 [@add_event_handler, full_key, Map.drop(new_value, [:msg, :key])]
               ]}

          {_, new_value} ->
            new_handlers = handlers ++ [{:put, handler_id, new_value}]

            {new_handlers,
             patches ++
               [
                 [@remove_event_handler, full_key, event],
                 [@add_event_handler, full_key, Map.drop(new_value, [:msg, :key])]
               ]}
        end
      end)

    state
    |> add_patches(new_patches)
    |> add_handlers(new_handlers)
  end

  defp put_lazy_tree(state = %{lazy_trees: trees}, key, value) do
    %{state | lazy_trees: Map.put(trees, key, value)}
  end

  defp add_patches(state = %{patches: patches}, new_patches) do
    %{state | patches: patches ++ new_patches}
  end

  defp add_handlers(state = %{handlers: handlers}, new_handlers) do
    %{state | handlers: handlers ++ new_handlers}
  end

  defp add_node(state, path, key, node) when is_binary(node) do
    add_patches(state, [[@add_node, path, node]])
  end

  defp add_node(state = %{handlers: handlers}, path, key, node) do
    keyed_node = {key, node}

    {new_handlers, node_without_handlers} = extract_event_handlers(path, keyed_node)

    encoded_node = encode_node(state, path, node_without_handlers)

    handler_patches =
      Enum.map(new_handlers, fn {:put, _, handler} ->
        [@add_event_handler, handler.key, Map.drop(handler, [:msg, :key])]
      end)

    state
    |> add_patches([[@add_node, path, encoded_node] | handler_patches])
    |> add_handlers(new_handlers)
  end

  defp replace_node(state, path, key, node) when is_binary(node) do
    add_patches(state, [[@replace_node, path ++ [key], node]])
  end

  # TODO: create @remove_event_handler patches for the DOM
  defp replace_node(state = %{handlers: handlers}, path, key, node) do
    keyed_node = {key, node}

    {new_handlers, node_without_handlers} = extract_event_handlers(path, keyed_node)

    encoded_node = encode_node(state, path, node_without_handlers)

    handler_patches =
      Enum.map(new_handlers, fn {:put, _, handler} ->
        [@add_event_handler, handler.key, Map.drop(handler, [:msg, :key])]
      end)

    state
    |> add_patches([[@replace_node, path ++ [key], encoded_node] | handler_patches])
    |> add_handlers(new_handlers)
  end

  defp prevent_default(:click), do: true
  defp prevent_default(:submit), do: true
  defp prevent_default(_), do: false

  defp build_event_handler({type, msg}, key) when is_list(msg) do
    build_event_handler(Keyword.put(msg, :event, type), key)
  end

  defp build_event_handler({type, msg}, key) do
    build_event_handler([event: type, msg: msg], key)
  end

  defp build_event_handler(handler, key) do
    prevent_default =
      Keyword.get_lazy(handler, :prevent_default, fn ->
        handler
        |> Keyword.get(:event)
        |> prevent_default()
      end)

    handler
    |> Map.new()
    |> Map.put_new(:prevent_default, prevent_default)
    |> Map.put_new(:stop_propagation, false)
    |> Map.put(:key, key)
  end

  def extract_event_handlers(_path, node = {_key, {:program, _, _}}) do
    {[], node}
  end

  def extract_event_handlers(_path, node = {_key, text}) when is_binary(text) do
    {[], node}
  end

  def extract_event_handlers(path, {key, {tag, attributes, children}}) do
    full_key = path ++ [key]
    string_key = Enum.join(full_key, ".")

    node_handlers =
      attributes
      |> Keyword.get_values(:on)
      |> Enum.reduce([], fn handlers, acc ->
        acc ++
          Enum.map(handlers, fn handler ->
            handler = build_event_handler(handler, full_key)

            type = Map.get(handler, :event)

            {:put, string_key <> "." <> Kernel.to_string(type), handler}
          end)
      end)

    new_attributes = Keyword.delete(attributes, :on)

    {all_handlers, new_children} =
      Enum.reduce(children, {node_handlers, []}, fn node, {handlers, children} ->
        {child_handlers, child} = extract_event_handlers(full_key, node)
        {handlers ++ child_handlers, children ++ [child]}
      end)

    {all_handlers, {key, {tag, new_attributes, new_children}}}
  end

  def encode_node(state, path, {key, {:program, program, params}}) do
    ["program", program, params]
  end

  def encode_node(state, path, {key, text}) when is_binary(text) do
    text
  end

  def encode_node(state, path, {key, {:lazy, fun, args}}) do
    encode_node(state, path, {key, Map.get(state.lazy_trees, {fun, args})})
  end

  def encode_node(state, path, {key, {tag, attributes, children}}) do
    key = path ++ [key]

    attributes =
      attributes
      |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
      |> Enum.into(%{})

    children =
      if is_list(children) do
        Enum.map(children, fn node ->
          encode_node(state, key, node)
        end)
      else
        children
      end

    [tag, attributes, children]
  end

  def from_html_string(html) do
    case Floki.parse(html) do
      [root | _] -> {0, from_floki_element(root)}
      [] -> {0, nil}
      root -> {0, from_floki_element(root)}
    end
  end

  def from_floki_attributes([]) do
    []
  end

  def from_floki_attributes([[key = "data-whistle-navigation", value] | rest]) do
    [{String.to_existing_atom(key), value} | from_floki_attributes(rest)]
  end

  def from_floki_attributes([["data-" <> _, value] | rest]) do
    from_floki_attributes(rest)
  end

  def from_floki_attributes([["on", handler] | rest]) do
    [{:on, [{String.to_existing_atom(handler),nil}]} | from_floki_attributes(rest)]
  end

  def from_floki_attributes([[key, value] | rest]) do
    [{String.to_existing_atom(key), value} | from_floki_attributes(rest)]
  end

  def from_floki_element(nil) do
    nil
  end

  def from_floki_element(element) when is_binary(element) do
    Whistle.Html.text(element)
  end

  def from_floki_element(["program", program, params]) do
    {:program, program, params}
  end

  def from_floki_element(["script", attributes, [""]]) do
    from_floki_element(["script", attributes, []])
  end

  def from_floki_element([tag, attributes, children]) do
    children =
      children
      |> Enum.with_index()
      |> Enum.map(fn {node, index} ->
        {index, from_floki_element(node)}
      end)

    {tag, from_floki_attributes(attributes), children}
  end

  defp attributes_to_string(attributes) do
    attributes
    |> Enum.map(fn
      {:on, _} ->
        ""

      {:value, _} ->
        ""

      {:required, _} ->
        ""

      {key, value} ->
        ~s(#{key}="#{value}")
    end)
    |> Enum.join(" ")
  end

  def node_to_string(node = {_, _, _}) do
    node_to_string({0, node})
  end

  def node_to_string({_, text}) when is_binary(text) do
    to_string(text)
  end

  def node_to_string({key, {tag, attributes, children}}) do
    children =
      children
      |> Enum.map(&node_to_string/1)
      |> Enum.join("")

    if tag in ["link", "input", "hr", "br", "meta"] and children == "" do
      ~s(<#{tag} #{attributes_to_string(attributes)}/>)
    else
      ~s(<#{tag} #{attributes_to_string(attributes)}>#{children}</#{tag}>)
    end
  end

  defp zip([lh | lt], [rh | rt]) do
    [{lh, rh} | zip(lt, rt)]
  end

  defp zip([], []), do: []
  defp zip([lh = {key, _} | lt], []), do: zip([lh | lt], [{key, nil}])
  defp zip([], [rh = {key, _} | rt]), do: zip([{key, nil}], [rh | rt])
end
