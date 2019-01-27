defmodule Whistle.Router do
  @registry Application.get_env(:whistle, :program_registry, Elixir.Registry)
  @supervisor Application.get_env(:whistle, :program_supervisor, Elixir.DynamicSupervisor)

  defp build_children({router, args}) do
    http_server =
      case args do
        [] ->
          []

        args ->
          [{Whistle.HttpServer, Keyword.put(args, :routers, [router])}]
      end

    [
      {@registry, [keys: :unique, name: Module.concat(router, Registry)]},
      {@supervisor, [name: Module.concat(router, Supervisor), strategy: :one_for_one]}
    ] ++ http_server
  end

  def start_link(args = {router, _args}) do
    Supervisor.start_link(build_children(args), name: router, strategy: :one_for_one)
  end

  def child_spec(args = {router, _args}) do
    children = build_children(args)

    default = %{
      id: router,
      start: {Supervisor, :start_link, [children, [name: router, strategy: :one_for_one]]},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  @doc """
  Returns the full URL of the Websocket Handler.
  """
  def url(%Plug.Conn{} = conn, router) do
    url_config = Keyword.get(router.__config(), :url, [])

    scheme = Keyword.get(url_config, :scheme, scheme(conn))
    port = Keyword.get(url_config, :port, port(conn))
    host = Keyword.get(url_config, :host, conn.host)

    IO.iodata_to_binary([
      http_to_ws_scheme(scheme),
      "://",
      host,
      request_url_port(scheme, port),
      router.__path()
    ])
  end

  defp scheme(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-proto") do
      ["https"] -> :https
      ["http"] -> :http
      _ -> conn.scheme
    end
  end

  defp port(conn) do
    with [port] <- Plug.Conn.get_req_header(conn, "x-forwarded-port"),
         {port, ""} <- Integer.parse(port) do
      port
    else
      _ -> conn.port
    end
  end

  defp http_to_ws_scheme(:http), do: "ws"
  defp http_to_ws_scheme(:https), do: "wss"

  defp request_url_port(:http, 80), do: ""
  defp request_url_port(:https, 443), do: ""
  defp request_url_port(_, port), do: [?:, Integer.to_string(port)]

  defmacro __before_compile__(_env) do
    quote do
      def __match(_) do
        {:error, :not_found}
      end
    end
  end

  defmacro __using__(path: path) do
    path_info = String.split(path, "/", trim: true)

    quote do
      # @behaviour Whistle.Router
      import Whistle.Router, only: [match: 3]

      @before_compile Whistle.Router

      def __config() do
        Application.get_env(Application.get_application(__MODULE__), __MODULE__, [])
      end

      def child_spec(_args) do
        Whistle.Router.child_spec({__MODULE__, __config()})
      end

      def start_link(_args) do
        Whistle.Router.start_link({__MODULE__, __config()})
      end

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
