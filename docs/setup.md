# Setup Whistle

To start a project, you need to add the `Whistle.HttpServer` child specification to your application supervisor like this:

```elixir
# lib/my_app/application.ex

children = [
  {Whistle.HttpServer, [
    http: [port: 4000], # settings passed to Cowboy
    plug: MyAppWeb.Plug, # Specify your own Plug to be called
    routers: [MyAppWeb.ProgramRouter]
  ]}
]
```

You can always define and use a config yourself if you wish:

```elixir
# config/dev.exs

config :my_app, :whistle_http, [
  http: [port: 4000],
  plug: MyAppWeb.Plug, # Specify your Plug to be called
  routers: [MyAppWeb.ProgramRouter]
]

# lib/my_app/application.ex

children = [
  {Whistle.HttpServer, Application.get_env(:my_app, :whistle_http)}
]
```

Now let's define the main Plug that is going to serve normal HTTP requests before we make any WebSocket connections, here you can run any plugs you might need. In this case, we are just serving the Javascript file with `Plug.Static` and rendering our counter program.

```elixir
# lib/my_app_web/plug.ex

defmodule MyAppWeb.Plug do
  use Plug.Builder

  plug(Plug.Logger)

  plug(Plug.Static,
    at: "/",
    from: :my_app,
    gzip: false,
    only: ~w(css js favicon.ico robots.txt)
  )

  plug(Whistle.Program.Plug,
    router: MyAppWeb.ProgramRouter,
    program: "counter"
  )
end
```

Don't forget to copy the Javascript library:

```
$ mix deps.get
$ mkdir -p priv/static/js
$ cp deps/whistle/priv/whistle.js priv/static/js/
```

And change your view to return a root HTML element:

```elixir
def view(state, _session) do
  ~H"""
  <html>
    <head></head>
    <body>
      <div>
        <button on-click={{ :increment }}>+</button>
        <span>The current number is: {{ state }}></span>
        <button on-click={{ :decrement }}>-</button>
      </div>
    </body>
  </html>
  """
end
```

Run your application:

```
$ iex -S mix
```

Now navigate to http://localhost:4000/ to see your awesome counter!
