# Whistle
[![Hex.pm](https://img.shields.io/hexpm/v/whistle.svg)](https://hex.pm/packages/whistle) [![Build Status](https://travis-ci.org/boudra/whistle.svg?branch=master)](https://travis-ci.org/boudra/whistle) [![Inline docs](http://inch-ci.org/github/boudra/whistle.svg)](http://inch-ci.org/github/boudra/whistle) [![Coverage Status](https://coveralls.io/repos/github/boudra/whistle/badge.svg)](https://coveralls.io/github/boudra/whistle)

<br>

Whistle allows you to write interactive dynamic web apps entirely in Elixir, it manages the state of your app in the server and streams the UI to a dumb client via Websockets.

- Documentation: [https://hexdocs.pm/whistle](https://hexdocs.pm/whistle)
- Example Chat Application: [boudra/whistle-chat](https://github.com/boudra/whistle-chat)

:warning: **This project is in heavy development, it's not production ready and APIs will change** :warning:

## Roadmap

What has been done, and what is left to do:

- [x] Program orchestrating, program error recovery, client auto-reconnections
- [x] Distributed programs via Horde
- [x] Program and client message communication and broadcasting
- [x] Lazy Virtual DOM trees to optimize diffing
- [x] Initial render via HTTP, then pickup updates via WebSockets
- [x] Full screen program mode with browser history to build Single Page Applications with Server Side Rendering :rocket:
- [x] Embed programs inside of other programs (like React components)
- [ ] Built-in Session persistence helpers
- [ ] Rewrite front-end library in ES6+/Typescript for easier development
- [ ] Write front-end library tests
- [ ] DOM list patching (reordering, inserting)
- [x] HTML string or EEx template file to VDOM tree in the view

## Installation

```elixir
def deps do
  [
    {:whistle, "~> 0.1.0"},

    # optional
    {:jason, "~> 1.0"}, # for encoding and decoding JSON
    {:horde, "~> 0.4.0"} # for distributing the program processes
  ]
end
```

## Getting started

The router is where everything starts, it defines the path of the Websocket listener and what routes match to what programs.

Here is an example:

```elixir
# lib/my_app_web/program_router.ex

defmodule MyAppWeb.ProgramRouter do
  use Whistle.Router, "/ws"

  match("counter", MyAppWeb.ExampleProgram, %{})
end
```

This is how the browser knows which Program to mount:

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
    ~H"""
    <div>
      <button on-click=#{{:change, 1}}>+</button>
      <span>The current number is: #{state}</span>
      <button on-click=#{{:change, -1}}>-</button>
    </div>
    """
    # This will get compiled to:
    # Html.div([], [
    #  Html.button([on: [click: {:change, 1}]], "+"),
    #  Html.span([], "The current number is: #{state}"),
    #  Html.button([on: [click: {:change, -1}]], "-")
    # ])
  end
end
```

Now all you need to do is add the router in your supervision tree, a router will spawn a dynamic Supervisor and Registry to keep track of all the program instances, you can run as many different routers as you want:

```elixir
# lib/my_app/application.ex

children = [
  {MyAppWeb.ProgramRouter, []}
]
```

## Running a standalone Whistle project

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

  plug(:index)

  def index(conn, _opts) do
    conn
    |> Whistle.Program.fullscreen(MyAppWeb.ProgramRouter, "counter")
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

Now navigate to http://localhost:4000/ to see your awesome counter!

## Integrating Whistle with an existing Phoenix endpoint

Because Whistle is based on Plug and Cowboy, it can also work alongside Phoenix.

All we need to do is add the router handlers to the Cowboy dispatch options.

Pass a list of all your routers as an argument to the `build_handlers/1` helper:

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

Once the handlers have been added, you can embed a program in your views like so:

```elixir
<%= raw(Whistle.Program.embed(conn, MyAppWeb.ProgramRouter, "counter", %{})) %>
```

Make sure you include the [Javscript](/docs/javascript.md) library, you can also embed the program using the Javascript API:

```javascript
import { Whistle } from 'js/whistle';

const socket = Whistle.open("ws://localhost:4000/socket");
const target = document.getElementById("target");
const program = socket.mount(target, "counter", {});
```

