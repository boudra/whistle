defmodule Whistle.HttpServer do
  def child_spec(opts) do
    dispatch_rules = dispatch(Keyword.get(opts, :routers, []), Keyword.get(opts, :plug, nil))

    children =
      Enum.flat_map([:http, :https], fn scheme ->
        opts
        |> Keyword.get(scheme, false)
        |> case do
          false ->
            []

          opts ->
            cowboy_opts = Keyword.put_new(opts, :dispatch, dispatch_rules)

            [{Plug.Cowboy, [scheme: scheme, plug: nil, options: cowboy_opts]}]
        end
      end)
      |> IO.inspect()

    default = %{
      id: __MODULE__,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def build_handlers(routers) do
    routers
    |> Enum.map(fn router ->
      {router.__path(), Whistle.SocketHandler, {router, []}}
    end)
  end

  defp dispatch(routers, plug) do
    plug_handler =
      if is_nil(plug) do
        []
      else
        [{:_, Plug.Cowboy.Handler, {plug, []}}]
      end

    [
      {:_, build_handlers(routers) ++ plug_handler}
    ]
  end
end
