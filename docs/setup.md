# Setup Whistle

To start a project, you need to configure your HTTP server, the Router will start it automatically if it's configured:

```elixir
# config/config.exs

config :my_app, MyAppWeb.ProgramRouter,
  http: [port: 4000],
  url: [port: 4000, scheme: :http],
  plug: MyAppWeb.Plug
```

Now let's define the main Plug that is going to serve normal HTTP requests before we make any WebSocket connections, here you can run any plugs you might need. In this case, we are just serving the Javascript file with `Plug.Static` and rendering our counter program.

The Plug will automatically call and render your program.

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
