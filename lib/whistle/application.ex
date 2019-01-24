defmodule Whistle.Application do
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

  defmacro __before_compile__(env) do
    routes = Module.get_attribute(env.module, :routes)

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
      unquote_splicing(matches)

      def __match(_) do
        {:error, :not_found}
      end
    end
  end

  defmacro __using__(_) do
    quote do
      use Whistle.Program
      alias Whistle.Application
      require Whistle.Application
      import Whistle.Application, only: [route: 2, route: 3]

      Module.register_attribute(__MODULE__, :routes, accumulate: true)
      @before_compile Whistle.Application

      def update({:_whistle_navigate, uri}, state, session) do
        case Application.update_route(__MODULE__, uri, state, session) do
          {:ok, state, session} ->
            {:reply, state, session, ["whistle_push_state", uri]}
        end
      end

      def update({:_whistle_update_path, uri}, state, session) do
        case Application.update_route(__MODULE__, uri, state, session) do
          {:ok, state, session} ->
            {:ok, state, session}
        end
      end

      def view(state, session) do
        route = Map.get(session, unquote(@route_key))

        apply(__MODULE__, route, [state, session])
      end
    end
  end

  defmacro route(path, module, fun) do
    quote do
      @routes {unquote(path), unquote(module), unquote(fun)}
    end
  end

  defmacro route(path, fun) do
    quote do
      @routes {unquote(path), __MODULE__, unquote(fun)}
    end
  end


  def update_route(program, uri, state, session) do
    %{query: query, path: path} = URI.parse(uri)

    path_info = Application.path_to_segments(path)

    query_params =
      if is_nil(query) do
        %{}
      else
        URI.decode_query(query)
      end

    case program.__match(path_info) do
      {:ok, route, params} ->
        {:ok, state, Map.put(session, @route_key, route)}
    end
  end
end
