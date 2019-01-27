# Whistle
[![Hex.pm](https://img.shields.io/hexpm/v/whistle.svg)](https://hex.pm/packages/whistle) [![Build Status](https://travis-ci.org/boudra/whistle.svg?branch=master)](https://travis-ci.org/boudra/whistle) [![Inline docs](http://inch-ci.org/github/boudra/whistle.svg)](http://inch-ci.org/github/boudra/whistle) [![Coverage Status](https://coveralls.io/repos/github/boudra/whistle/badge.svg)](https://coveralls.io/github/boudra/whistle)

<br>

Whistle allows you to write interactive dynamic web apps entirely in Elixir, it manages the state of your app in the server and streams the UI to a dumb client via Websockets.

- Documentation: [https://hexdocs.pm/whistle](https://hexdocs.pm/whistle)
- Example Chat Application: [boudra/whistle-chat](https://github.com/boudra/whistle-chat)

**This project is still in development, some things might not work and the interface will definetly change**

## Roadmap

What has been done, and what features are planned:

- [x] Program orchestrating, program error recovery, client auto-reconnections
- [x] Program and client message communication and broadcasting
- [x] Lazy Virtual DOM trees to reduce unecessary rendering and diffing
- [x] Integrate Virtual DOM with Elixir's AST so it can be generated at compile-time
- [x] Initial render via HTTP, then stream updates via WebSockets
- [x] Full screen program mode with browser history to build Single Page Applications with Server Side Rendering :rocket:
- [x] Embed programs inside of other programs (like React components)
- [x] HTML string or EEx template file to VDOM tree in the view
- [x] "Single Page Applications" with built in routing and browser history support
- [x] Code reloading for code Programs without having to restart
- [ ] Authentication helpers?
- [ ] Session and Virtual DOM persistence between refreshes
- [ ] Rewrite front-end library in ES6+/Typescript for easier development
- [ ] Write front-end library tests
- [ ] DOM list patching (reordering, inserting)
- [ ] Trigger classes depending on state like `classes: [wrapper: true, loading: :disconnected]` this will trigger loading when the socket is disconnected or `[spin: :loading]` for a form submit waiting for a response.
- [ ] Program state as a CRDT to distribute programs?

## Installation

```elixir
def deps do
  [
    {:whistle, git: "https://github.com/boudra/whistle", ref: "master"},
    # {:whistle, "~> 0.1.0"},

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

Use `Whistle.Router.match/3` to define program routes, the router will spawn a new program instance for every unique route.

The program is a module where we specify how to manage and render its state, here is a very simple example:

```elixir
# lib/my_app_web/programs/example_program.ex

defmodule MyAppWeb.ExampleProgram do
  use Whistle.Program

  def init(_params) do
    {:ok, 0}
  end

  def update(:increment, state, session) do
    {:ok, state + 1, session}
  end

  def update(:decrement, state, session) do
    {:ok, state - 1, session}
  end

  def view(state, _session) do
    ~H"""
    <div>
      <button on-click={{ :increment }}>+</button>
      <span>The current number is: {{ state }}></span>
      <button on-click={{ :decrement }}>-</button>
    </div>
    """
  end
end
```

Programs can also be nested:

```elixir
defmodule MyAppWeb.ProgramRouter do
  use Whistle.Router, "/ws"

  match("main", MyAppWeb.MainProgram, %{})
  match("counter", MyAppWeb.ExampleProgram, %{})
end

defmodule MyAppWeb.MainProgram do
  use Whistle.Program

  def init(_params) do
    {:ok, %{}}
  end

  def authorize(_state, socket, _params) do
    {:ok, socket, %{path: "/"}}
  end

  def update({:navigate, path}, state, session) do
    {:ok, state, %{session | path: path}}
  end

  def view(state, %{path: "/"}) do
    ~H"""
    <div>
      <h1>Homepage</h1>
      <a on-click={{ {:navigate, "/counter"} }}>
        Go to the counter
      </a>
    </div>
    """
  end

  def view(state, %{path: "/counter"}) do
    ~H"""
    <div>
      <h1>Counter</h1>
      <a on-click={{ {:navigate, "/"} }}>
        Back to the homepage
      </a>
      <program name="counter" params={{ %{} }}> />
    </div>
    """
  end
end

```

Check out the docs for `Whistle.Program` to see all the callbacks available and the different ways to render the view.

All you need to do now is add the router in your supervision tree, a router will spawn a dynamic Supervisor and Registry to keep track of all the program instances, you can run as many different routers as you want:

```elixir
# lib/my_app/application.ex

children = [
  {MyAppWeb.ProgramRouter, []}
]
```

Now that you have a router and a program, it's time to link everything up:

- [Integrate with your existing Phoenix project](/docs/phoenix.md)
- [Running Whislte on it's own](/docs/setup.md)
