defmodule Whistle.Navigation do
  alias Whistle.Html
  require Whistle.Html

  @route_key :__route

  def link(path, attributes, children) do
    Html.a(
      attributes ++
        [
          href: path,
          on: [
            click: [
              prevent_default: true,
              msg: {:_whistle_navigate, path_to_segments(path)}
            ]
          ]
        ],
      children
    )
  end

  def html(attributes, children) do
    Html.html(attributes ++ [on: [history: &{:_whistle_update_path, &1}]], children)
  end

  def path_to_segments(path) do
    String.split(path, "/", trim: true)
  end

  defmacro __using__({_, _, routes}) do
    matches =
      for {path, route} <- routes do
        expr_components = path_to_segments(path)

        expr_match =
          Enum.map(expr_components, fn
            ":" <> name -> {String.to_atom(name), [], nil}
            part -> part
          end)

        params_map =
          Enum.reduce(expr_components, [], fn
            ":" <> name, acc when byte_size(name) > 0 ->
              acc ++
                [
                  {name, {String.to_atom(name), [], nil}}
                ]

            _, acc ->
              acc
          end)

        quote do
          def __match(unquote(expr_match)) do
            new_params = Map.new(unquote(params_map))

            {:ok, unquote(route), new_params}
          end
        end
      end

    quote do
      alias Whistle.Navigation

      unquote_splicing(matches)

      def update({:_whistle_navigate, uri}, state, session) do
        case Navigation.update_route(__MODULE__, uri, state, session) do
          {:ok, state, session} ->
            {:reply, state, session, ["whistle_push_state", uri]}
        end
      end

      def update({:_whistle_update_path, uri}, state, session) do
        case Navigation.update_route(__MODULE__, uri, state, session) do
          {:ok, state, session} ->
            {:ok, state, session}
        end
      end

      def view(state, session) do
        route = Map.get(session, @route_key)

        apply(__MODULE__, route, [state, session])
      end
    end
  end

  def update_route(program, uri, state, session) do
    %{query: query, path: path} = URI.parse(uri)

    path_info = Navigation.path_to_segments(path)

    query_params =
      if is_nil(query) do
        %{}
      else
        URI.decode_query(query)
      end

    case __MODULE__.__match(path_info) do
      {:ok, route, params} ->
        {:ok, state, Map.put(session, @route_key, route)}
    end
  end
end
