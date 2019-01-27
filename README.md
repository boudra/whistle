# Whistle
[![Hex.pm](https://img.shields.io/hexpm/v/whistle.svg)](https://hex.pm/packages/whistle) [![Build Status](https://travis-ci.org/boudra/whistle.svg?branch=master)](https://travis-ci.org/boudra/whistle) [![Inline docs](http://inch-ci.org/github/boudra/whistle.svg)](http://inch-ci.org/github/boudra/whistle) [![Coverage Status](https://coveralls.io/repos/github/boudra/whistle/badge.svg)](https://coveralls.io/github/boudra/whistle)

<br>

Whistle is a web framework for building interactive dynamic web apps or small components entirely in Elixir, it manages the state of your app in the server and streams the UI to a dumb client via Websockets.

- Documentation: [https://hexdocs.pm/whistle](https://hexdocs.pm/whistle)

For an example Single Page Application including Server Side Rendering and routing, that uses most of Whistle's features, check out this chat application:

- Code: [boudra/whistle-chat](https://github.com/boudra/whistle-chat)
- Demo: [https://lumpy-some-piglet.gigalixirapp.com/](https://lumpy-some-piglet.gigalixirapp.com/)

## FAQs

**What is a Router?**

A Router is a module that defines what routes match what programs, every unique route string will spawn a unique program instance. The router also supervises the [Program Regsitry](https://hexdocs.pm/whistle/Whistle.Program.Registry.html), the Program Supervisor and the [HTTP server](https://hexdocs.pm/whistle/setup.html) if there is one.

**What is a Program?**

A program is a stateful component that runs as an Erlang process, this is where we define how the state looks like, how it's updated and how it's rendered.

**What is the difference between a Fullscreen Program and an Embeded Program?**

A fullscreen Program is when a Program renders the whole HTML document, including the `<head>` and the `<body>`. Fullscreen programs normally take control of the routing too.

**How does the Virtual DOM work?**

The Virtual DOM is an in-memory representation of the client's DOM that lives in the server, every time a Program's state changes, Whistle will render it compare the new Virtual DOM against the old one, and send minimal changes to the client via WebSockets.

Whistle's Virtual DOM is represented as follows:

```elixir
# {key, {tag, {attributes, children}}}
{0, {"div", {[class: "red"], [{0, "first"}, {1, "second"}]}}}
```
You can use the macros to generate it (preferrable):

```elixir
Html.div([class: "red"], [
  "first",
  "second"
])
```

Or the `~H` sigil (note that this is not EEx, it is a custom templating format similar to Mustache):

```elixir
~H"""
<div class="red">first second</div>
"""
```

The Virtual DOM consists of pairs of tuples so that it can also be a valid Elixir AST and be able to generate most of it at compile time:

```elixir
iex> a = "text"
iex> Html.span([], [a])
{0, {"span", {[], [{0, {:a, [], nil}}]}}}
```

Whistle also provided functions to render a VDOM to string, this is used to render a HTML response when rendering Programs in Plug.

```elixir
iex> Html.span([], ["text"]) |> Whistle.Html.Dom.node_to_string()
<span>text</span>
```


## Roadmap

**Please remember that this project is still in it's very early stages, test coverage is low, some things might not work and the API will most definetly change**

What has been done, and what features are planned:

- [x] Program orchestrating, program error recovery, client auto-reconnections
- [x] Program and client message communication and broadcasting
- [x] Lazy Virtual DOM trees to reduce unecessary rendering and diffing
- [x] Integrate Virtual DOM with Elixir's AST so it can be generated at compile-time
- [x] Initial render via HTTP, then stream updates via WebSockets
- [x] Full screen program mode with routing and browser history to build Single Page Applications with Server Side Rendering :rocket:
- [x] HTML string template file to VDOM tree in the view
- [x] "Single Page Applications" with built in routing and browser history support
- [x] Code reloading for code Programs without having to restart
- [ ] **Session and Virtual DOM persistence between refreshes, to avoid sending the DOM every time the Websocket connects**
- [ ] **Full EEx support for templates**
- [ ] **Testing helpers**
- [ ] Authentication helpers?
- [ ] Integration with Ecto for building changeset forms
- [ ] Rewrite front-end library in ES6+/Typescript for easier development
- [ ] Write front-end library tests
- [ ] DOM list patching (reordering, inserting)
- [ ] Trigger classes depending on state like `classes: [wrapper: true, loading: :disconnected]` this will trigger loading when the socket is disconnected or `[spin: :loading]` for a form submit waiting for a response
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

Check out the docs for `Whistle.Program` to see all the callbacks available and the different ways to render the view.

All you need to do now is add the router in your supervision tree, a router will spawn a dynamic Supervisor and Registry to keep track of all the program instances, you can run as many different routers as you want:

```elixir
# lib/my_app/application.ex

children = [
  {MyAppWeb.ProgramRouter, []}
]
```

Now that you have a router and a program set up, it's time to link everything up with a server, Whistle works with Plug so it doesn't need Phoenix to run, but you can integrate with an existing Phoenix project too:

- [Running with Whistle and Plug](https://hexdocs.pm/whistle/setup.html)
- [Integrate with your existing Phoenix project](https://hexdocs.pm/whistle/phoenix.html)
