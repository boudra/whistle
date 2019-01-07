defmodule Whistle.Router do
  @registry Application.get_env(:whistle, :program_registry, Elixir.Registry)
  @supervisor Application.get_env(:whistle, :program_supervisor, Elixir.DynamicSupervisor)

  def child_spec(router) do
    children = [
      {@registry, [keys: :unique, name: Module.concat(router, Registry)]},
      {@supervisor, [name: Module.concat(router, Supervisor), strategy: :one_for_one]}
    ]

    default = %{
      id: router,
      start: {Supervisor, :start_link, [children, [name: router, strategy: :one_for_one]]},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def url(%Plug.Conn{} = conn, router) do
    IO.iodata_to_binary([
      http_to_ws_scheme(conn.scheme),
      "://",
      conn.host,
      request_url_port(conn.scheme, conn.port),
      router.__path()
    ])
  end

  defmacro __using__(path: path) do
    path_info = String.split(path, "/", trim: true)

    quote do
      # @behaviour Whistle.Router
      import Whistle.Router

      def __path() do
        unquote(path)
      end

      def __path_info() do
        unquote(path_info)
      end
    end
  end

  defmacro match(expr, program, params) do
    expr_components = String.split(expr, ":")

    expr_match =
      Enum.map(expr_components, fn
        "*" -> {:_, [], nil}
        "*" <> name -> {String.to_atom(name), [], nil}
        part -> part
      end)

    params_map =
      Enum.reduce(expr_components, [], fn
        "*" <> name, acc when byte_size(name) > 0 ->
          acc ++
            [
              {name, {String.to_atom(name), [], nil}}
            ]

        _, acc ->
          acc
      end)

    quote do
      def __match(unquote(expr_match)) do
        new_params = Map.merge(unquote(params), Map.new(unquote(params_map)))

        {:ok, unquote(program), new_params}
      end
    end
  end
end
