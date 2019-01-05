# Whistle

Whistle allows you to write interactive dynamic web apps entirely in Elixir.

Documentation: [https://hexdocs.pm/whistle](https://hexdocs.pm/whistle).
Example Chat Application: [boudra/whistle-chat](https://github.com/boudra/whistle-chat).

## How does it work?

Whistle is influenced by [The Elm Architecture](https://guide.elm-lang.org/architecture/), Whistle moves this architecture to the server and streams DOM changes to the client via WebSockets.

Then navigate to http://localhost:4000/index.html to preview the app

## Installation

```elixir
def deps do
  [
    {:whistle, "~> 0.1.0"}
  ]
end
```

## Getting started

The router defines the path of the Websocket listener and what routes match to what programs, like this:

```elixir
# lib/my_app_web/program_router.ex

defmodule MyAppWeb.ProgramRouter do
  use Whistle.Router, "/ws"

  match("counter", MyAppWeb.ExampleProgram, %{})
end
```

```
+---------+          +-------------+                  +-----------+
| Client  |  /ws ->  |   Router    |  chat:*lobby ->  |  Program  |
+---------+          +-------------+                  +-----------+
```

The program is a module where we specify how to manage and render its state, here is a very simple example:

```elixir
# lib/my_app_web/programs/example_program.ex

defmodule MyAppWeb.ExampleProgram do
  use Whistle.Program

  def init(_params) do
    {:ok, 0}
  end

  def authorize(_state, socket, _params) do
    {:ok, socket, nil}
  end

  def update({:change, n}, state, session) do
    {:ok, state + n, session}
  end

  def view(state, _session) do
    Html.div([], [
      Html.button([on: [click: {:change, 1}]], "+"),
      Html.text("The current number is: #{state}"),
      Html.button([on: [click: {:change, -1}]], "-")
    ])
  end
end
```

Now all you need to do is add the router in your supervision tree, a router will spawn a dynamic Supervisor and Registry to keep track of all the program instances, you can run as many different routers as you want:

```elixir
# lib/my_app/application.ex

children = [
  {Whistle.Router, MyAppWeb.ProgramRouter}
]
```

## Integrating Whistle with an existing Phoenix endpoint

Whistle provides a Http server module (with **Plug & Cowboy2**) that works out of the box, but it can also work alongside Phoenix.

All we need to do is add the router handlers to the Cowboy dispatch options, this is the important line, you need to list all your routers as an argument to `build_handlers/1`

```elixir
Whistle.HttpServer.build_handlers([MyAppWeb.ProgramRouter])
```

Here is an example:

```elixir
config :myapp, MyAppWeb.Endpoint,
  http: [dispatch: [
          {:_, Whistle.HttpServer.build_handlers([MyAppWeb.ProgramRouter]) ++ [
              {:_, Phoenix.Endpoint.Cowboy2Handler, {MyAppWeb.Endpoint, []}}
            ]}]]
```

Check out the [Phoenix.CowBoy2.Adapter docs](https://hexdocs.pm/phoenix/Phoenix.Endpoint.Cowboy2Adapter.html) for more info.

## Running a standalone Whistle Http server

Whistle tries to avoid using config and tries to keep things composable:

```elixir
# lib/my_app/application.ex

children = [
  {Whistle.HttpServer, [
    http: [port: 4000],
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
  plug: MyAppWeb.Plug, # Specify your own Plug to be called
  routers: [MyAppWeb.ProgramRouter]
]

# lib/my_app/application.ex

children = [
  {Whistle.HttpServer, Application.get_env(:my_app, :whistle_http)}
]
```

This is your main Plug, here you can run any plugs you might need. In this case, we are just serving the Javascript file with `Plug.Static` and rendering a very basic `index.html` file that mounts our component.

```elixir
# lib/my_app_web/plug.ex

defmodule MyAppWeb.Plug do
  use Plug.Builder

  # Mount will render an initial HTML and then get updated when the Websocket connects
  defp index_html(conn) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title></title>
    </head>
    <body>
      #{Whistle.Program.mount(conn, MyAppWeb.ProgramRouter, "counter", %{})}
      <script src="/js/whistle.js"></script>
    </body>
    </html>
    """
  end

  plug Plug.Logger

  plug Plug.Static,
    at: "/",
    from: :whistle_chat,
    gzip: false,
    only: ~w(css js favicon.ico robots.txt)

  plug :index

  def index(conn, _opts) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, index_html(conn))
  end
end
```

Don't forget to copy the Javascript library:

```
$ mix deps.get
$ mkdir -p priv/static/js
$ cp deps/whistle/priv/whistle.js priv/static/js/
```

Run your application:

```
$ iex -S mix
```
